pragma solidity ^0.8.24;

import {ModuleCoreTest} from "./ModuleCoreTest.k.sol";
import {TestCorkHook} from "./TestCorkHook.k.sol";

import {Id, Pair}        from "../../../contracts/libraries/Pair.sol";
import {Guard}     from "../../../contracts/libraries/Guard.sol";
import {DepegSwap} from "../../../contracts/libraries/DepegSwapLib.sol";
import {MathHelper} from "../../../contracts/libraries/MathHelper.sol";
import {IVault} from "../../../contracts/interfaces/IVault.sol";
import {Withdrawal} from "../../../contracts/core/Withdrawal.sol";

import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {TestAsset}     from "./TestAsset.k.sol";
import {TestERC20} from "./TestERC20.t.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MarketSnapshot} from "Cork-Hook/lib/MarketSnapshot.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";

import "./Constants.k.sol";

struct ProofState {
    uint256 lvTotalSupply;
    uint256 lvBalanceUser;
    uint256 moduleCoreRaBalance;
    uint256 userRaBalance;
    uint256 ammRaBalance;
    uint256 vaultCtBalance;
    uint256 psmRaLocked;
    uint256 lvReserve;
    uint256 dsTotalSupply;
    uint256 dsBalanceFlashSwapRouter;
    uint256 ctTotalSupply;
    uint256 ctBalanceModuleCore;
    uint256 ctBalanceHook;
    uint256 ctBalanceUser;
    uint256 lpTotalSupply;
    uint256 lpBalanceModuleCore;
}

contract LiquidityVaultTest is ModuleCoreTest {
    ProofState private preState;
    ProofState private posState;

    function setUp() public override {
        super.setUp();
        setSymbolicState(1,0);
    }
    
    function test_depositLV_revert_after_expiry(uint256 amount, uint256 raTolerance, uint256 ctTolerance) public {
        vm.assume(!moduleCore.getVaultIsDepositPaused(id));
        vm.assume(amount != 0);

        vm.assume(moduleCore.getDsIsExpired(id));
        vm.expectRevert(Guard.Expired.selector);
        moduleCore.depositLv(id, amount, raTolerance, ctTolerance);
    }

    function _assumeDepositLvPreState(uint256 amount, address depositor, address ra) internal {
        vm.assume(amount < ETH_UPPER_BOUND);
        // assume that LVDepositNotPaused(id)
        vm.assume(!moduleCore.getVaultIsDepositPaused(id));
        // avoid ICommon.ZeroDeposit()
        vm.assume(amount != 0);
        // assume safeBeforeExpired
        vm.assume(!moduleCore.getDsIsExpired(id));

        TestAsset(moduleCore.getVaultLvAsset(id)._address).setSymbolicBalanceOf(depositor, "lvBalanceOfUser");
    }


    function _mockCallsDepositLV(uint256 amount) internal
        returns (uint256 splitted, uint256 raAmount, uint256 ctAmount, uint256 receivedLv) {
        // Mock call to MathHelper.calculatePercentageFee
        // Proved in MathHelperTest.testCalculatePercentageFee that splitted <= amount
        splitted = kevm.freshUInt(32, "splitted");
        vm.assume(splitted > 0);
        vm.assume(splitted <= amount);
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculatePercentageFee.selector), abi.encode(splitted));

        // Mock call to RouterState.getCurrentPriceRatio
        // TODO: prove that  0 < ctRatio <= type(uint256).max - 1e18
        uint256 ctRatio = kevm.freshUInt(32, "ctRatio");
        vm.assume(ctRatio != 0);
        vm.mockCall(address(flashSwapRouter), abi.encodeWithSelector(RouterState.getCurrentPriceRatio.selector), abi.encode(uint256(0), ctRatio));

        // Mock call to MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice
        // Proved in MathHelperTest.testCalculateProvideLiquidityAmountBasedOnCtPrice that ctAmount <= amountLeft
        // NOTE: If ctAMount == 0 or ctAmount == amountLeft (which implies raAmount == 0) then the invariant does not hold
        // because moduleCore stays with the ra amountLeft that it does not return to the user, neither converts into
        // CT and DS neither send to AMM
        uint256 amountLeft = amount - splitted;
        ctAmount = kevm.freshUInt(32, "ctAmount");
        vm.assume(0 < ctAmount);
        vm.assume(ctAmount < amountLeft);

        raAmount = amountLeft - ctAmount;
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice.selector), abi.encode(raAmount, ctAmount));

        // Mock call to MathHelper.calculateDepositLv
        // TODO: prove that calculateDepositLv correctly computes NAV
        receivedLv = freshUInt256Bounded("receivedLv");
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculateDepositLv.selector), abi.encode(receivedLv));
    }

    function _stateSnapshot(ProofState storage state, address depositor) internal {
        TestAsset lvToken = TestAsset(moduleCore.lvAsset(id));
        state.lvTotalSupply = lvToken.totalSupply();
        state.lvBalanceUser = lvToken.balanceOf(depositor);

        Pair memory pair = moduleCore.getPairInfo(id);
        state.moduleCoreRaBalance = IERC20(pair.ra).balanceOf(address(moduleCore));
        state.userRaBalance = IERC20(pair.ra).balanceOf(depositor);
        state.ammRaBalance = IERC20(pair.ra).balanceOf(address(hook));
        
        state.vaultCtBalance = moduleCore.getVaultBalances(id).ctBalance;
        state.psmRaLocked = moduleCore.getPsmBalances(id).ra.locked;
        state.lvReserve = flashSwapRouter.getLvReserve(id, moduleCore.getDsId(id));

        (address ds, address ct) = moduleCore.getDsCtPair(id);
        state.dsTotalSupply =  TestAsset(ds).totalSupply();
        state.dsBalanceFlashSwapRouter = TestAsset(ds).balanceOf(address(flashSwapRouter));
        state.ctTotalSupply = TestAsset(ct).totalSupply();
        state.ctBalanceModuleCore = TestAsset(ct).balanceOf(address(moduleCore));
        state.ctBalanceHook = TestAsset(ct).balanceOf(address(hook));
        state.ctBalanceUser = TestAsset(ct).balanceOf(depositor);

        state.lpTotalSupply = IERC20(lpBase).totalSupply();
        state.lpBalanceModuleCore = IERC20(lpBase).balanceOf(address(moduleCore));
    }

    function _assertDepositLVStateChanges(
        uint256 amount, uint256 splitted, uint256 raAmount, uint256 ctAmount, uint256 receivedLv)
        internal view {
        // LVToken expected changes - receivedLV is minted to depositor
        assertEq(posState.lvTotalSupply, preState.lvTotalSupply + receivedLv);
        assertEq(posState.lvBalanceUser, preState.lvBalanceUser + receivedLv);

        // Ra balances expected changes
        uint256 raAdded = hook.raAdded();
        uint256 raDust = raAmount - raAdded;
        assertEq(posState.userRaBalance, preState.userRaBalance - amount + raDust);
        // The following assertion will not hold if ctAmount == 0
        assertEq(posState.moduleCoreRaBalance, preState.moduleCoreRaBalance + splitted + ctAmount);
        assertEq(posState.ammRaBalance, preState.ammRaBalance + raAdded);

        // Cork state expected changes
        assertEq(posState.vaultCtBalance, preState.vaultCtBalance + splitted);
        assertEq(posState.psmRaLocked, preState.psmRaLocked + splitted + ctAmount);
        assertEq(posState.lvReserve, preState.lvReserve + splitted + ctAmount);

        // DSToken expected changes
        assertEq(posState.dsTotalSupply, preState.dsTotalSupply + splitted + ctAmount);
        assertEq(posState.dsBalanceFlashSwapRouter, preState.dsBalanceFlashSwapRouter + splitted + ctAmount);

        // CTToken expected changes
        uint256 ctAdded = hook.ctAdded();
        uint256 ctDust = ctAmount - ctAdded;
        assertEq(posState.ctTotalSupply, preState.ctTotalSupply + splitted + ctAmount);
        assertEq(posState.ctBalanceModuleCore, preState.ctBalanceModuleCore + splitted);
        assertEq(posState.ctBalanceHook, preState.ctBalanceHook + ctAdded);
        assertEq(posState.ctBalanceUser, preState.ctBalanceUser + ctDust);

        // LP expected changes
        uint256 lpMinted = hook.lpMinted();
        assertEq(posState.lpTotalSupply, preState.lpTotalSupply + lpMinted);
        assertEq(posState.lpBalanceModuleCore, preState.lpBalanceModuleCore + lpMinted);
    }


    function test_depositLV_correctness(uint256 amount, uint256 raTolerance, uint256 ctTolerance) public {
        address ra = moduleCore.getPairInfo(id).ra;
        address depositor = raDepositor(ra, amount);
        bool wasVaultInitialized = moduleCore.getVaultInitialized(id);

        _assumeDepositLvPreState(amount, depositor, ra);

        (uint256 splitted, uint256 raAmount, uint256 ctAmount, uint256 receivedLv) = _mockCallsDepositLV(amount);
        
        _stateSnapshot(preState, depositor);

        // Assume invariants hold before the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assume);
        _invariant_ctBalance(Mode.Assume);
        _invariant_lvReserve(Mode.Assume);

        vm.prank(depositor);
        moduleCore.depositLv(id, amount, raTolerance, ctTolerance);

        // Assert invariants are preserved by the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assert);
        _invariant_ctBalance(Mode.Assert);
        _invariant_lvReserve(Mode.Assert);

        _stateSnapshot(posState, depositor);

        if(!wasVaultInitialized) {
            receivedLv = amount - splitted;
        }

        if(raAmount == 0 || ctAmount == 0) {
            raAmount = 0;
            ctAmount = 0;
        }

        // Assert that the state changes as expected
        _assertDepositLVStateChanges(amount, splitted, raAmount, ctAmount, receivedLv);
    }

    function _assumeRedeemLvPreState(uint256 amount) internal {
        vm.assume(amount < ETH_UPPER_BOUND);
        // assume nonReentrant
        _setReentrancyGuardFalse();
        // assume that LVWithdrawalNotPaused(id)
        vm.assume(!moduleCore.getVaultIsWithdrawalPaused(id));
        // assume safeBeforeExpired
        vm.assume(!moduleCore.getDsIsExpired(id));
    }

    function _mockCallsRedeemLV(uint256 amount) internal returns (uint256,uint256) {
        // Mock call to MathHelper.calculatePercentageFee
        // Proved in MathHelperTest.testCalculatePercentageFee that fee <= amount
        uint256 fee = kevm.freshUInt(32, "fee");
        vm.assume(fee > 0);
        // 5 ether is the upper bound of self.vault.config.fee
        vm.assume(fee <= (amount * 5 ether) / (100 * UNIT));
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculatePercentageFee.selector), abi.encode(fee));

        // Mock call to MathHelper.calculateRedeemLv
        // TODO: prove that calculateRedeemLv correctly computes ctReceived, dsReceived and lpLiquidated
        (uint256 ctReceived, uint256 dsReceived, uint256 lpLiquidated, uint256 paReceived, uint256 idleRaReceived) = 
            (freshUInt256Bounded("ctReceived"),
             freshUInt256Bounded("dsReceived"), 
             freshUInt256Bounded("lpLiquidated"),
             freshUInt256Bounded("paReceived"),
             freshUInt256Bounded("idleRaReceived"));
        MathHelper.RedeemResult memory result = 
            MathHelper.RedeemResult(ctReceived, dsReceived, lpLiquidated, paReceived, idleRaReceived);
        vm.assume(ctReceived <= moduleCore.getVaultBalances(id).ctBalance);
        (address ds, address ct) = moduleCore.getDsCtPair(id);
        vm.assume(ctReceived <= moduleCore.getVaultBalances(id).ctBalance);
        vm.assume(dsReceived <= flashSwapRouter.getLvReserve(id, moduleCore.getDsId(id)));
        vm.assume(lpLiquidated <= IERC20(lpBase).balanceOf(address(moduleCore)));
        vm.assume(paReceived <= IERC20(moduleCore.getPairInfo(id).pa).balanceOf(address(moduleCore)));
        vm.assume(idleRaReceived <= IERC20(moduleCore.getPairInfo(id).ra).balanceOf(address(moduleCore)));
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculateRedeemLv.selector), abi.encode(result));

        address withdrawalContract = moduleCore.withdrawalContract();
        vm.mockCall(withdrawalContract, abi.encodeWithSelector(Withdrawal.add.selector), abi.encode(bytes32(0)));

        return (fee, lpLiquidated);
    }

    function _assertRedeemLVStateChanges(uint256 amount, uint256 lpLiquidated, IVault.RedeemEarlyResult memory result)
        internal view {
        // LVToken expected changes - receivedLV is minted to depositor
        assertEq(posState.lvTotalSupply, preState.lvTotalSupply - amount);
        assertEq(posState.lvBalanceUser, preState.lvBalanceUser - amount);

        // Ra balances expected changes
        assertEq(posState.userRaBalance, preState.userRaBalance + result.raReceivedFromAmm);
        assertEq(posState.moduleCoreRaBalance, preState.moduleCoreRaBalance);
        assertEq(posState.ammRaBalance, preState.ammRaBalance - result.raReceivedFromAmm);

        // Cork state expected changes
        assertEq(posState.vaultCtBalance, preState.vaultCtBalance - result.ctReceivedFromVault);
        assertEq(posState.psmRaLocked, preState.psmRaLocked);
        assertEq(posState.lvReserve, preState.lvReserve - result.dsReceived);

        // DSToken expected changes
        assertEq(posState.dsTotalSupply, preState.dsTotalSupply);
        assertEq(posState.dsBalanceFlashSwapRouter, preState.dsBalanceFlashSwapRouter - result.dsReceived);

        // CTToken expected changes
        assertEq(posState.ctTotalSupply, preState.ctTotalSupply);
        assertEq(posState.ctBalanceModuleCore, preState.ctBalanceModuleCore - result.ctReceivedFromVault);
        assertEq(posState.ctBalanceHook, preState.ctBalanceHook - result.ctReceivedFromAmm);
        assertEq(posState.ctBalanceUser, preState.ctBalanceUser + result.ctReceivedFromVault + result.ctReceivedFromAmm);

        // LP expected changes
        assertEq(posState.lpTotalSupply, preState.lpTotalSupply - lpLiquidated);
        assertEq(posState.lpBalanceModuleCore, preState.lpBalanceModuleCore - lpLiquidated);
    }

    function test_redeemLV_correctness(uint256 amount, uint256 amountOutMin, uint256 ammDeadline) public {
        IVault.RedeemEarlyParams memory redeemParams = IVault.RedeemEarlyParams(id, amount, amountOutMin, ammDeadline);
        hook.setAmountOutMin(amountOutMin);

        _assumeRedeemLvPreState(amount);
        
        (uint256 fee, uint256 lpLiquidated) = _mockCallsRedeemLV(amount);

        address redeemer = lvRedeemer(amount + fee);

        _stateSnapshot(preState, redeemer);

        // Assume invariants hold before the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assume);
        _invariant_ctBalance(Mode.Assume);
        _invariant_lvReserve(Mode.Assume);

        vm.prank(redeemer);
        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemParams);

        // Assert invariants are preserved by the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assert);
        _invariant_ctBalance(Mode.Assert);
        _invariant_lvReserve(Mode.Assert);

        _stateSnapshot(posState, redeemer);

        // Assert that the state changes as expected
        _assertRedeemLVStateChanges(amount, lpLiquidated, result);
    }
}