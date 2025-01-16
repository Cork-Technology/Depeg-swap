
pragma solidity ^0.8.24;

pragma solidity ^0.8.24;

import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {Withdrawal} from "../../../contracts/core/Withdrawal.sol";

import {TestERC20} from "./TestERC20.t.sol";
import {KontrolTest} from "./KontrolTest.k.sol";
import {TestAsset} from "./TestAsset.k.sol";

import {Id, Pair} from "../../../contracts/libraries/Pair.sol";
import {
    State,
    PsmPoolArchive,
    VaultState,
    VaultAmmLiquidityPool,
    Balances,
    VaultConfig,
    VaultBalances,
    VaultWithdrawalPool
} from "../../../contracts/libraries/State.sol";
import {RedemptionAssetManager} from "../../../contracts/libraries/RedemptionAssetManagerLib.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {DepegSwap} from "../../../contracts/libraries/DepegSwapLib.sol";
import {LvAsset} from "../../../contracts/libraries/LvAssetLib.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {IDsFlashSwapCore} from "../../../contracts/interfaces/IDsFlashSwapRouter.sol";

/// @title TestModuleCore Contract, used for testing ModuleCore contract, mostly here for getter functions
contract TestModuleCore is ModuleCore, KontrolTest {
    using BitMaps for BitMaps.BitMap;

    constructor() ModuleCore() {
        kevm.symbolicStorage(address(this));

        bytes32 initializeSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

        vm.store(address(this), initializeSlot, bytes32(0));
    }

    function withdrawalContract() public view returns (address) {
        return WITHDRAWAL_CONTRACT;
    }

    // ------------------------------ GLOBAL GETTERS ------------------------------
    function getDsId(Id id) external view returns (uint256) {
        return states[id].globalAssetIdx;
    }

    function setSymbolicState(Id id, uint256 dsId, Pair memory key, address ds, address ct, address lv) external {
        states[id].globalAssetIdx = dsId;

        Withdrawal _withdrawalContract = new Withdrawal(address(0));
        _setWithdrawalContract(address(_withdrawalContract));

        setPairInfo(id, key);
        setDsCtPair(id, dsId, ds, ct);
        setSymbolicPsm(id);
        setSymbolicVault(id, lv);
    }

    function setPairInfo(Id id, Pair memory key) internal {
        states[id].info = key;
        // WARNING: We will make expiryInterval concrete so it can info.toId() can be concrete
        // Alternatively we can mockCalls to toId() so it returns the keccak with expiryInterval = 0
    }

    function getPairInfo(Id id) external view returns (Pair memory) {
        return states[id].info;
    }

    function getDs(Id id, uint256 dsId) external view returns (DepegSwap memory) {
        return states[id].ds[dsId];
    }

    function setDsCtSymbolicPair(Id id, uint256 dsId, address ds, address ct) external {
        states[id].ds[dsId]._address = ds;
        states[id].ds[dsId].ct = ct;
    }
    
    function setDsCtPair(Id id, uint256 dsId, address ds, address ct) internal {
        states[id].ds[dsId]._address = address(ds);
        states[id].ds[dsId].ct = address(ct);
        states[id].ds[dsId].expiredEventEmitted = kevm.freshBool();
        uint256 ctRedeemed = freshUInt256Bounded("ctRedeemed");
        states[id].ds[dsId].ctRedeemed = ctRedeemed;
    }

    function getDsCtPair(Id id) external view returns (address ds, address ct) {
        uint256 dsId = states[id].globalAssetIdx;
        ds = states[id].ds[dsId]._address;
        ct = states[id].ds[dsId].ct;
    }

    function getIsInitialized(Id id) external view returns (bool) {
        return states[id].info.pa != address(0) && states[id].info.ra != address(0);
    }

    function getDsIsInitialized(Id id, uint256 dsId) external view returns (bool) {
        return states[id].ds[dsId]._address != address(0) && states[id].ds[dsId].ct != address(0);
    }

    function getDsIsExpired(Id id) external view returns (bool) {
        uint256 dsId = states[id].globalAssetIdx;
        return TestAsset(states[id].ds[dsId]._address).isExpired();
    }
    //--------------------------------------------------------------------------------

    // ------------------------------ PSM GETTERS ------------------------------
    function getPsmBalances(Id id) external view returns (Balances memory) {
        return states[id].psm.balances;
    }

    function getPsmPoolArchiveRaAccrued(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].raAccrued;
    }

    function getPsmPoolArchivePaAccrued(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].paAccrued;
    }

    function getPsmPoolArchiveCtAttributed(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].ctAttributed;
    }

    function getPsmPoolArchiveAttributedToRollover(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].attributedToRolloverProfit;
    }

    function getPsmPoolArchiveRolloverClaims(Id id, uint256 dsId, address user) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].rolloverClaims[user];
    }

    function getPsmPoolArchiveRolloverProfit(Id id, uint256 dsId) external view returns (uint256) {
        return states[id].psm.poolArchive[dsId].rolloverProfit;
    }

    function getPsmRepurchaseFeePercentage(Id id) external view returns (uint256) {
        return states[id].psm.repurchaseFeePercentage;
    }

    function getPsmBaseRedemptionFeePercentage(Id id) external view returns (uint256) {
        return states[id].psm.psmBaseRedemptionFeePercentage;
    }

    function getPsmLiquiditySeparated(Id id, uint256 dsId) external view returns (bool) {
        return states[id].psm.liquiditySeparated.get(dsId);
    }

    function getPsmIsDepositPaused(Id id) external view returns (bool) {
        return states[id].psm.isDepositPaused;
    }

    function getPsmIsWithdrawalPaused(Id id) external view returns (bool) {
        return states[id].psm.isWithdrawalPaused;
    }

    function setSymbolicPsm(Id id) internal {
        Balances storage balances = states[id].psm.balances;
        RedemptionAssetManager storage ra = balances.ra;
        ra._address = states[id].info.ra;
        ra.locked = freshUInt256Bounded("ra.locked");
        ra.free = freshUInt256Bounded("ra.free");
        balances.dsBalance = freshUInt256Bounded("balances.dsBalance");
        balances.paBalance = freshUInt256Bounded("balances.paBalance");
        balances.ctBalance = freshUInt256Bounded("balances.ctBalance");
        uint256 psmBaseRedemptionFee = kevm.freshUInt(32, "psmBaseRedemptionFee");
        vm.assume(psmBaseRedemptionFee < 5 ether);
        states[id].psm.psmBaseRedemptionFeePercentage = psmBaseRedemptionFee;
        states[id].psm.poolArchive[states[id].globalAssetIdx].rolloverProfit = freshUInt256Bounded("psm.rolloverProfit");
        // ...
    }
    //--------------------------------------------------------------------------------

    // ------------------------------ VAULT GETTERS ------------------------------
    function getVaultBalances(Id id) external view returns (VaultBalances memory) {
        return states[id].vault.balances;
    }

    function getVaultConfig(Id id) external view returns (VaultConfig memory) {
        return states[id].vault.config;
    }

    function getVaultLvAsset(Id id) external view returns (LvAsset memory) {
        return states[id].vault.lv;
    }

    function getVaultLpLiquidated(Id id, uint256 dsId) external view returns (bool) {
        return states[id].vault.lpLiquidated.get(dsId);
    }

    function getVaultWithdrawalPool(Id id) external view returns (VaultWithdrawalPool memory) {
        return states[id].vault.pool.withdrawalPool;
    }

    function getVaultAmmLiquidityPool(Id id) external view returns (VaultAmmLiquidityPool memory) {
        return states[id].vault.pool.ammLiquidityPool;
    }

    function getWithdrawEligible(Id id, address user) external view returns (uint256) {
        return states[id].vault.pool.withdrawEligible[user];
    }

    function getVaultIsDepositPaused(Id id) external view returns (bool) {
        return states[id].vault.config.isDepositPaused;
    }

    function getVaultIsWithdrawalPaused(Id id) external view returns (bool) {
        return states[id].vault.config.isWithdrawalPaused;
    }

    function getVaultCtHeldPercentage(Id id) external view returns (uint256) {
        return states[id].vault.ctHeldPercetage;
    }

    function getVaultInitialized(Id id) external view returns (bool) {
        return states[id].vault.initialized;
    }

    function setSymbolicVault(Id id, address lv) internal {
        VaultState storage vault = states[id].vault;
        vault.balances.ra._address = states[id].info.ra;
        vault.balances.ctBalance = freshUInt256Bounded("vault.balances.ctBalance");

        vault.lv._address = lv;
        vault.lv.locked = freshUInt256Bounded("vault.lv.locked");

        uint256 ctHeldPercentage = freshUInt256Bounded("ctHeldPercentage");
        vm.assume(ctHeldPercentage >= 0.001 ether);
        vm.assume(ctHeldPercentage <= 100 ether);
        vault.ctHeldPercetage = ctHeldPercentage;
        vault.initialized = kevm.freshBool();

        uint256 lvFee = kevm.freshUInt(32, "lvFee");
        vm.assume(lvFee < 5 ether);
        vault.config.fee = lvFee;
        
        // ...
    }
    // ----------------------------UTILS-----------------------------------------------

    function _assumeNewAddress(address freshAddress, Id id) external view {
        vm.assume(freshAddress != states[id].info.ra);
        vm.assume(freshAddress != states[id].info.pa);
        
        uint256 dsId = states[id].globalAssetIdx;
        vm.assume(freshAddress != states[id].ds[dsId]._address);
        vm.assume(freshAddress != states[id].ds[dsId].ct);
    }

    // ----------- AUXILIARY MOCK FUNCTION IMPLEMENTATIONS--------------------------------

    function mockRedeemRaWithCtDs(Id id, uint256 amount) external returns (uint256 ra) {
        /* A more extensive version of the mock & proof should check whether 
            - CT & DS tokens got burned
            - the `locked` variable is updated correctly
            - withdrawals are not paused

            For example, 

            ra = amount;
            self.psm.balances.ra.unlockTo(owner, ra);
            ERC20Burnable(ds.ct).burnFrom(owner, amount);
            ERC20Burnable(ds._address).burnFrom(owner, amount);
        */

        address _ra = states[id].info.ra;

        uint256 received = freshUInt256("received_from_redeem");
        // Assuming no overflow occurs on transfer to the caller
        unchecked {
            vm.assume(TestERC20(_ra).balanceOf(msg.sender) + received >= received);
        }
        // Assuming this contract has enough tokens to transfer
        vm.assume(TestERC20(_ra).balanceOf(address(this)) >= received);

        TestERC20(_ra).transfer(msg.sender, received);

        return received;
    }

    function mockDepositPsm(Id id, uint256 amount) external returns (uint256 received, uint256 exchangeRate) {
        /* A more extensive version of the mock & proof should check whether 
            - deposits are not paused
            - ds has not expired
            - exchangeRate is actually 1
        */

        State storage state = states[id];
        DepegSwap storage ds = state.ds[state.globalAssetIdx];

        received = amount;

        /* TODO:
        state.psm.balances.ra.lockFrom(amount, msg.sender);
        ds.issue(msg.sender, received);
        */

        // Assuming that no overflows occur during `mint`
        unchecked {
            vm.assume(TestERC20(ds._address).balanceOf(msg.sender) + received >= received);
            vm.assume(TestERC20(ds.ct).balanceOf(msg.sender) + received >= received);
        }

        return (received, 1);
    }
}
