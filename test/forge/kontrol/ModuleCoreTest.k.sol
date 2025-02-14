pragma solidity ^0.8.24;

import {TestModuleCore} from "./TestModuleCore.k.sol";
import {TestAssetFactory} from "./TestAssetFactory.k.sol";
import {TestFlashSwapRouter} from "./TestFlashSwapRouter.k.sol";
import {TestCorkConfig} from "./TestCorkConfig.k.sol";
import {TestCorkHook} from "./TestCorkHook.k.sol";
import {TestAsset} from "./TestAsset.k.sol";
import {TestERC20} from "./TestERC20.t.sol";

import {Id, Pair, PairLibrary} from "../../../contracts/libraries/Pair.sol";
import {ICommon} from "../../../contracts/interfaces/ICommon.sol";
import {PeggedAsset, PeggedAssetLibrary} from "../../../contracts/libraries/PeggedAssetLib.sol";
import {DepegSwap} from "../../../contracts/libraries/DepegSwapLib.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {ProtocolFeeControllerTest} from "v4-periphery/lib/v4-core/src/test/ProtocolFeeControllerTest.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LiquidityToken} from "Cork-Hook/CorkHook.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {KontrolTest} from "./KontrolTest.k.sol";

contract ModuleCoreTest is KontrolTest {
    using PairLibrary for Pair;

    uint256 constant UNIT = 1e18;

    TestModuleCore      internal moduleCore;
    TestCorkConfig      internal corkConfig;
    TestFlashSwapRouter internal flashSwapRouter;
    TestAssetFactory    internal assetFactory;
    TestCorkHook        internal hook;

    // Supplementary contracts for CorkHook
    PoolManager internal manager;
    ProtocolFeeControllerTest internal feeController;
    TestAsset internal token0;
    TestAsset internal token1;
    TestERC20 internal lpBase;

    Id id;

    function setUp() public virtual {
        // Setting up a UniV4 hook contract
        manager = new PoolManager();
        // WARNING: For the purpose of the current proofs is enough lpBase to be ERC20. Change it to LIquidityToken is necessary.
        lpBase = new TestERC20("LP");
        hook = new TestCorkHook(address(manager), address(lpBase));

        corkConfig = new TestCorkConfig();
        moduleCore = new TestModuleCore();
        flashSwapRouter = new TestFlashSwapRouter(address(corkConfig), address(moduleCore));
        assetFactory = new TestAssetFactory();

        corkConfig.setModuleCore(address(moduleCore));
        
        flashSwapRouter.initialize(address(corkConfig));
        flashSwapRouter.setModuleCore(address(moduleCore));
        flashSwapRouter.setHook(address(hook));

        assetFactory.initialize();
        assetFactory.transferOwnership(address(moduleCore));

        moduleCore.initialize(
            address(assetFactory),
            address(hook),
            address(flashSwapRouter),
            address(corkConfig)
        );
    }


    function setSymbolicState(uint256 dsId, uint256 hyia) internal {
        address pa = address(new TestERC20("PA"));
        address ra = address(new TestERC20("RA"));

        // TODO: try to make expiryInterval symbolic later
        Pair memory key = PairLibrary.initalize(pa, ra, 0);
        id = key.toId();

        uint256 expiry = kevm.freshUInt(32, "expiry");
        vm.assume(expiry != 0);
        uint256 psmExchangeRate = freshUInt256Bounded("psmExchangeRate");
        vm.assume(psmExchangeRate != 0);

        address ds = address(new TestAsset("DS","RA-PA", address(moduleCore), expiry, psmExchangeRate, dsId));
        address ct = address(new TestAsset("CT","RA-PA", address(moduleCore), expiry, psmExchangeRate, dsId));
        address lv = address(new TestAsset("LV","RA-PA", address(moduleCore), 0, 0, 0));

        TestERC20(ra).setSymbolicBalanceOf(address(moduleCore), "raBalanceOfModuleCore");
        TestERC20(pa).setSymbolicBalanceOf(address(moduleCore), "paBalanceOfModuleCore");
        TestAsset(ds).setSymbolicBalanceOf(address(moduleCore), "dsBalanceOfModuleCore");
        TestAsset(ct).setSymbolicBalanceOf(address(moduleCore), "ctBalanceOfModuleCore");

        TestERC20(ra).setSymbolicBalanceOf(address(hook), "raBalanceOfHook");
        TestERC20(ct).setSymbolicBalanceOf(address(hook), "ctBalanceOfHook");
        TestAsset(ds).setSymbolicBalanceOf(address(flashSwapRouter), "dsBalanceOfRouter");

        TestERC20(lpBase).setSymbolicBalanceOf(address(moduleCore), "lpBalanceOfModuleCore");
        TestERC20(lpBase).setSymbolicAllowance(address(moduleCore), address(hook), "lpAllowanceCoreHook");

        TestAsset(ds).setSymbolicAllowance(address(moduleCore), address(flashSwapRouter), "dsAllowanceCoreRouter");
        TestAsset(ct).setSymbolicAllowance(address(moduleCore), address(hook), "ctAllowanceCoreHook");
        TestERC20(ra).setSymbolicAllowance(address(moduleCore), address(hook), "raAllowanceCoreHook");

        moduleCore.setSymbolicState(id, dsId, key, ds, ct, lv);
        flashSwapRouter.setSymbolicState(id, dsId, ra, ds, ct, hyia);
    }

    function _setReentrancyGuardFalse() internal {
        bytes32 REENTRANCY_GUARD_STORAGE = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

        vm.store(address(moduleCore), REENTRANCY_GUARD_STORAGE, bytes32(0));
    }


    function raDepositor(address ra, uint256 amount) internal returns (address depositor) {
        depositor = address(0xABCDE);
        TestERC20(ra).setSymbolicBalanceOf(depositor, "raBalanceOfUser");
        TestERC20(ra).setSymbolicAllowance(depositor, address(moduleCore), "raAllowanceUserCore");

        uint256 depositorRaBalance = IERC20(ra).balanceOf(depositor);
        vm.assume(depositorRaBalance >= amount);

        uint256 allowance = IERC20(ra).allowance(depositor, address(moduleCore));
        vm.assume(allowance >= amount);

        (address ds, address ct) = moduleCore.getDsCtPair(id);
        TestAsset(ds).setSymbolicBalanceOf(address(depositor), "dsBalanceOfUser");
        TestAsset(ct).setSymbolicBalanceOf(address(depositor), "ctBalanceOfUser");
    }

    function psmRedeemerWithDs(uint256 amount, uint256 dsProvided) internal returns (address redeemer) {
        redeemer = address(0xABCDE);

        Pair memory info = moduleCore.getPairInfo(id);

        TestERC20(info.pa).setSymbolicBalanceOf(redeemer, "paBalanceOfUser");
        TestERC20(info.pa).setSymbolicAllowance(redeemer, address(moduleCore), "paAllowanceUserCore");
        uint256 redeemerPaBalance = IERC20(info.pa).balanceOf(redeemer);
        vm.assume(redeemerPaBalance >= amount);
        uint256 allowancePa = IERC20(info.pa).allowance(redeemer, address(moduleCore));
        vm.assume(allowancePa >= amount);

        TestERC20(info.ra).setSymbolicBalanceOf(redeemer, "raBalanceOfUser");
        vm.assume(dsProvided <= IERC20(info.ra).balanceOf(address(moduleCore)));

        (address ds, address ct) = moduleCore.getDsCtPair(id);
        TestAsset(ds).setSymbolicBalanceOf(redeemer, "dsBalanceOfUser");
        uint256 redeemerDsBalance = IERC20(ds).balanceOf(redeemer);
        vm.assume(redeemerDsBalance >= dsProvided);

        TestAsset(ds).setSymbolicAllowance(redeemer, address(moduleCore), "dsAllowanceUserCore");
        uint256 allowanceDs = IERC20(ds).allowance(redeemer, address(moduleCore));
        vm.assume(allowanceDs >= dsProvided);

        TestAsset(ct).setSymbolicBalanceOf(redeemer, "ctBalanceOfUser");
    }

    function lvRedeemer(uint256 amount) internal returns (address redeemer) {
        redeemer = address(0xABCDE);
        TestAsset lvToken = TestAsset(moduleCore.lvAsset(id));
        lvToken.setSymbolicBalanceOf(redeemer, "lvBalanceOfUser");
        lvToken.setSymbolicAllowance(redeemer, address(moduleCore), "lvAllowanceUserCore");

        uint256 redeemerLvBalance = lvToken.balanceOf(redeemer);
        vm.assume(redeemerLvBalance >= amount);

        uint256 allowance = lvToken.allowance(redeemer, address(moduleCore));
        vm.assume(allowance >= amount);

        Pair memory info = moduleCore.getPairInfo(id);
        TestERC20(info.ra).setSymbolicBalanceOf(redeemer, "raBalanceOfUser");

        (address ds, address ct) = moduleCore.getDsCtPair(id);
        TestAsset(ds).setSymbolicBalanceOf(redeemer, "dsBalanceOfUser");
        TestAsset(ct).setSymbolicBalanceOf(redeemer, "ctBalanceOfUser");

        address withdrawalContract = moduleCore.withdrawalContract();
        TestERC20(info.ra).setSymbolicBalanceOf(withdrawalContract, "raBalanceOfWithdrawal");
        TestERC20(info.pa).setSymbolicBalanceOf(withdrawalContract, "paBalanceOfWithdrawal");
        TestAsset(ds).setSymbolicBalanceOf(withdrawalContract, "dsBalanceOfWithdrawal");
        TestAsset(ct).setSymbolicBalanceOf(withdrawalContract, "ctBalanceOfWithdrawal");
    }
    

    function _get_DS_CT_PA_RA(Id pairId) internal view returns (address ds, address ct, address ra, address pa) {
        (ds, ct) = moduleCore.getDsCtPair(pairId);
        
        Pair memory info = moduleCore.getPairInfo(pairId);
        ra = info.ra;
        pa = info.pa;
    }


    function _invariant_DS_CT_backed_PA_RA(Mode mode) internal view {
        (address dsToken, address ctToken, address ra, address pa) = _get_DS_CT_PA_RA(id);

        // Confirm if it's the totalSupply or the balances of these tokens
        uint256 dsTotalSupply = IERC20(dsToken).totalSupply();
        uint256 ctTotalSupply = IERC20(ctToken).totalSupply();

        _establish(mode, dsTotalSupply == ctTotalSupply);

        uint256 paBalance = IERC20(pa).balanceOf(address(moduleCore));
        uint256 raBalance = IERC20(ra).balanceOf(address(moduleCore));

        _establish(mode, dsTotalSupply == (paBalance + raBalance));
    }


    function _invariant_ctBalance(Mode mode) internal view {
        (, address ct) = moduleCore.getDsCtPair(id);
        _establish(mode, moduleCore.getVaultBalances(id).ctBalance == IERC20(ct).balanceOf(address(moduleCore)));
    }

    function _invariant_lvReserve(Mode mode) internal view {
        (address ds,) = moduleCore.getDsCtPair(id);
        uint256 dsId = moduleCore.getDsId(id);
        _establish(mode, flashSwapRouter.getLvReserve(id, dsId) == IERC20(ds).balanceOf(address(flashSwapRouter)));
    }
}