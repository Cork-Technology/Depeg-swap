pragma solidity ^0.8.24;

import {ModuleCoreTest} from "./ModuleCoreTest.k.sol";
import {TestAsset}     from "./TestAsset.k.sol";
import {TestERC20} from "./TestERC20.t.sol";

import {Id, Pair} from "../../../contracts/libraries/Pair.sol";
import {ICommon} from "../../../contracts/interfaces/ICommon.sol";
import {MathHelper} from "../../../contracts/libraries/MathHelper.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Constants.k.sol";

struct ProofState {
    uint256 moduleCoreRaBalance;
    uint256 depositorRaBalance;
    uint256 psmRaLocked; 
    uint256 dsTotalSupply;
    uint256 ctTotalSupply;
    uint256 dsBalanceDepositor;
    uint256 ctBalanceDepositor;
}

contract PsmTest is ModuleCoreTest {
    ProofState private preState;
    ProofState private posState;

    function setUp() public override {
        super.setUp();
        setSymbolicState(1,0);
    }

    function test_reinitialize_fail(
        address _pa,
        address _ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 psmBaseRedemptionFeePercentage,
        uint256 _expiryInterval)
    public {
        Pair memory key = Pair({pa: _pa, ra: _ra, expiryInterval: _expiryInterval});
        id = Id.wrap(keccak256(abi.encode(key)));

        vm.assume(moduleCore.getIsInitialized(id));
        vm.startPrank(address(corkConfig));
        vm.expectRevert(ICommon.AlreadyInitialized.selector);
        moduleCore.initializeModuleCore(_pa, _ra, lvFee, initialDsPrice, psmBaseRedemptionFeePercentage, _expiryInterval);
    }

    function _stateSnapshotDepositPSM(ProofState storage state, address depositor) internal {
        Pair memory pair = moduleCore.getPairInfo(id);
        state.moduleCoreRaBalance = IERC20(pair.ra).balanceOf(address(moduleCore));
        state.depositorRaBalance = IERC20(pair.ra).balanceOf(depositor);
        
        state.psmRaLocked = moduleCore.getPsmBalances(id).ra.locked;

        (address ds, address ct) = moduleCore.getDsCtPair(id);
        state.dsTotalSupply =  IERC20(ds).totalSupply();
        state.ctTotalSupply = IERC20(ct).totalSupply();
        state.dsBalanceDepositor = IERC20(ds).balanceOf(depositor);
        state.ctBalanceDepositor = IERC20(ct).balanceOf(depositor);
    }


    function _assertDepositLVStateChanges(uint256 amount) internal view {
        assertEq(posState.moduleCoreRaBalance, preState.moduleCoreRaBalance + amount);
        assertEq(posState.depositorRaBalance, preState.depositorRaBalance - amount);
        assertEq(posState.dsBalanceDepositor, preState.dsBalanceDepositor + amount);
        assertEq(posState.ctBalanceDepositor, preState.ctBalanceDepositor + amount);
        assertEq(posState.dsTotalSupply, preState.dsTotalSupply + amount);
        assertEq(posState.ctTotalSupply, preState.ctTotalSupply + amount);
        assertEq(posState.psmRaLocked, preState.psmRaLocked + amount);
    }


    function test_deposit_PSM_correctness(uint256 amount) public {
        vm.assume(amount != 0);
        vm.assume(amount < ETH_UPPER_BOUND);
        vm.assume(!moduleCore.getPsmIsDepositPaused(id));
        // assume safeBeforeExpired
        vm.assume(!moduleCore.getDsIsExpired(id));

        address ra = moduleCore.getPairInfo(id).ra;
        address depositor = raDepositor(ra, amount);

        _stateSnapshotDepositPSM(preState, depositor);

        // Assume invariants hold before the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assume);
        _invariant_ctBalance(Mode.Assume);
        _invariant_lvReserve(Mode.Assume);

        // Make the deposit
        vm.prank(depositor);
        (uint256 received, uint256 _exchangeRate) = moduleCore.depositPsm(id, amount);

        // Assert invariants are preserved by the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assert);
        _invariant_ctBalance(Mode.Assert);
        _invariant_lvReserve(Mode.Assert);

        _stateSnapshotDepositPSM(posState, depositor);

        // Assert that the state changes as expected
        _assertDepositLVStateChanges(amount);
    }

    function _mockCallsRedeemRaWithDs(uint256 amount) internal returns (uint256 raReceived, uint256 dsProvided) {
        // Proved in MathHelperTest.testCalculatePercentageFee that ra == amount * exchangeRates / UNIT
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculateEqualSwapAmount.selector), abi.encode(amount));
        // underflow check assumption
        vm.assume(amount <= moduleCore.getPsmBalances(id).ra.locked);
        
        dsProvided = amount;

        // Mock call to MathHelper.calculatePercentageFee
        // Proved in MathHelperTest.testCalculatePercentageFee that fee <= amount
        uint256 fee = kevm.freshUInt(32, "fee");
        // 5 ether is the upper bound of psmBaseRedemptionFeePercentage
        vm.assume(fee <= (amount * 5 ether) / (100 * UNIT));
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculatePercentageFee.selector), abi.encode(fee));

        raReceived = amount - fee;

        // We can mock this function with 0 because we are not using the returned values since hook.addLiquidity
        // also has a mocked implementation
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculateWithTolerance.selector), abi.encode(uint256(0),uint256(0)));
    
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
        uint256 ctAmount = kevm.freshUInt(32, "ctAmount");
        vm.assume(0 < ctAmount);
        vm.assume(ctAmount < fee);

        uint256 raAmount = fee - ctAmount;
        vm.mockCall(address(MathHelper), abi.encodeWithSelector(MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice.selector), abi.encode(raAmount, ctAmount));
    }


    function test_redeemRaWithDs_correctness(uint256 amount) public {
        vm.assume(amount < ETH_UPPER_BOUND);
        // assume nonReentrant
        _setReentrancyGuardFalse();
        // Assume PSM withdrawal is not paused
        vm.assume(!moduleCore.getPsmIsWithdrawalPaused(id));
        // assume safeBeforeExpired
        vm.assume(!moduleCore.getDsIsExpired(id));
        // assume exchangeRate is 1
        (address ds,) = moduleCore.getDsCtPair(id);
        vm.assume(TestAsset(ds).exchangeRate() == 1e18);

        (uint256 raReceived, uint256 dsProvided) = _mockCallsRedeemRaWithDs(amount);

        address redeemer = psmRedeemerWithDs(amount, dsProvided);

        //_stateSnapshotRedeemPSM(preState, redeemer);

        // Assume invariants hold before the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assume);
        _invariant_ctBalance(Mode.Assume);
        _invariant_lvReserve(Mode.Assume);

        // Redeem
        uint256 dsId = moduleCore.getDsId(id);
        vm.prank(redeemer);
        (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed) = moduleCore.redeemRaWithDs(id, dsId, amount);

        // Assume invariants hold before the function call
        _invariant_DS_CT_backed_PA_RA(Mode.Assert);
        _invariant_ctBalance(Mode.Assert);
        _invariant_lvReserve(Mode.Assert);

        //_stateSnapshotRedeemPSM(posState, redeemer);

        // Assert that the state changes as expected
    }
}