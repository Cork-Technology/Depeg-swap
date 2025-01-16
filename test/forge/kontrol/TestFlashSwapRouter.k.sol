pragma solidity ^0.8.24;

import "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";

import {KontrolTest} from "./KontrolTest.k.sol";
import {TestERC20} from "./TestERC20.t.sol";
import {TestAsset} from "./TestAsset.k.sol";
import {TestModuleCore} from "./TestModuleCore.k.sol";

/// @title TestFlashSwapRouter Contract, used for testing FlashSwapRouter contract, mostly here for getter functions
contract TestFlashSwapRouter is RouterState, KontrolTest {

    bytes32 constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;
    
    constructor(address config, address moduleCore) RouterState() {
        kevm.symbolicStorage(address(this));

        bytes32 initializeSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

        vm.store(address(this), initializeSlot, bytes32(0));

        bytes32 hasAdminRoleSlot = keccak256(abi.encode(msg.sender, keccak256(abi.encode(DEFAULT_ADMIN_ROLE, AccessControlStorageLocation))));
        vm.store(address(this), hasAdminRoleSlot, bytes32(0));
        
        bytes32 hasConfigRoleSlot = keccak256(abi.encode(config, keccak256(abi.encode(CONFIG, AccessControlStorageLocation))));
        vm.store(address(this), hasConfigRoleSlot, bytes32(0));

        bytes32 hasModuleCoreRoleSlot = keccak256(abi.encode(moduleCore, keccak256(abi.encode(MODULE_CORE, AccessControlStorageLocation))));
        vm.store(address(this), hasModuleCoreRoleSlot, bytes32(0));
    }

    function setSymbolicState(Id id, uint256 dsId, address ra, address ds, address ct, uint256 hyia) external {
        reserves[id].hiya = hyia;
        reserves[id].ds[dsId].ra = Asset(ra);
        reserves[id].ds[dsId].ct = Asset(ct);
        reserves[id].ds[dsId].ds = Asset(ds);
        uint256 lvReserve = freshUInt256Bounded("lvReserve");
        reserves[id].ds[dsId].lvReserve = lvReserve;
        uint256 psmReserve = freshUInt256Bounded("psmReserve");
        reserves[id].ds[dsId].psmReserve = psmReserve;
    }

    function assumeRollOverSale(Id id, uint256 dsId) external {
        vm.assume(block.number <= reserves[id].rolloverEndInBlockNumber);
        vm.assume(dsId > DsFlashSwaplibrary.FIRST_ISSUANCE);
    }

    // ------------------------------------------------------------ Getters ------------------------------ 
    function getAssetPair(Id id,uint256 dsId) external view returns (AssetPair memory) {
        return reserves[id].ds[dsId];
    }

    function getReserveSellPressurePercentage(Id id) external view returns (uint256) {
        return reserves[id].reserveSellPressurePercentage;
    }

    function getHiyeCumulated(Id id) external view returns (uint256) {
        return reserves[id].hiyaCumulated;
    }

    function getVhiyaCumulated(Id id) external view returns (uint256) {
        return reserves[id].vhiyaCumulated;
    }

    function getDecayDiscountRateInDays(Id id) external view returns (uint256) {
        return reserves[id].decayDiscountRateInDays;
    }

    function getRolloverEndInBlockNumber(Id id) external view returns (uint256) {
        return reserves[id].rolloverEndInBlockNumber;
    }

    function getHiya(Id id) external view returns (uint256) {
        return reserves[id].hiya;
    }

    // ------------------------------------------------------------ Auxiliary Mock Functions ------------------------------ 

    function CorkCallMockDsToRa(Id reserveId, address ra, address hook, address caller, uint256 actualRepaymentAmount, uint256 attributed, uint256 borrowed, uint256 dsId) external {
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];

        TestAsset(address(assetPair.ds)).approve(_moduleCore, attributed);
        TestAsset(address(assetPair.ct)).approve(_moduleCore, attributed);

        TestModuleCore psm = TestModuleCore(_moduleCore);

        uint256 received = psm.mockRedeemRaWithCtDs(reserveId, borrowed);
        // Assuming that the `received` RA from redeeming is sufficient to pay back the user 
        vm.assume(received >= attributed);

        uint256 repaymentAmount = received - attributed;
        // Assuming the remaining `repaymentAmount` is sufficient to pay back the loan,
        // for simplicity, assuming that they're equal and no dust is attributed to the user
        vm.assume(repaymentAmount == actualRepaymentAmount);

        if (actualRepaymentAmount > repaymentAmount) {
            revert IMathError.InsufficientLiquidity();
        } else if (actualRepaymentAmount < repaymentAmount) {
            // refund excess
            uint256 refunded = repaymentAmount - actualRepaymentAmount;
            // assuming no overflow on adding `refunded` to attributed
            unchecked {
                vm.assume(attributed + refunded >= attributed);
            }
            attributed += refunded;
        }

        // Assuming the contract has enough tokens to transfer and no overflows occur
        vm.assume(attributed <= type(uint256).max - actualRepaymentAmount);
        vm.assume(TestERC20(ra).balanceOf(address(this)) >= actualRepaymentAmount + attributed);

        // Sending the caller their RA
        TestERC20(ra).transfer(caller, attributed);
        // Repaying the flash loan
        TestERC20(ra).transfer(hook, actualRepaymentAmount);
    }

    function CorkCallMockRaToDs(Id reserveId, address ra, address hook, address caller, uint256 actualRepaymentAmount, uint256 dsAttributed, uint256 borrowed, uint256 provided, uint256 dsId) external {
        AssetPair storage assetPair = reserves[reserveId].ds[dsId];

        uint256 deposited = provided + borrowed;

        TestERC20(ra).approve(_moduleCore, deposited);

        TestModuleCore psm = TestModuleCore(_moduleCore);
        (uint256 received,) = psm.mockDepositPsm(reserveId, deposited);

        // Assuming `received` is sufficient to pay back the user and repay flash loan, as implemented in the actual function
        vm.assume(received >= dsAttributed - 1);
        uint256 repaymentAmount = received - dsAttributed;
        // Assuming the remaining `repaymentAmount` is sufficient to pay back the loan;
        // for simplicity, assuming they're equal and no dust is attributed to the user
        vm.assume(repaymentAmount == actualRepaymentAmount);

        {
            uint256 refunded;

            // not enough liquidity
            if (actualRepaymentAmount > received) {
                revert IMathError.InsufficientLiquidity();
            } else {
                refunded = received - actualRepaymentAmount;
                repaymentAmount = actualRepaymentAmount;
            }

            if (refunded > 0) {
                // refund the user with extra ct
                assetPair.ct.transfer(caller, refunded);
            }
        }

        // for rounding error protection
        dsAttributed -= 1;

        assert(received >= dsAttributed);

        // should be the same, we don't compare with the RA amount since we maybe dealing
        // with a non-rebasing token, in which case the amount deposited and the amount received will always be different
        // so we simply enforce that the amount received is equal to the amount attributed to the user

        // Assuming the contract has enough tokens to transfer
        vm.assume(TestAsset(address(assetPair.ds)).balanceOf(address(this)) >= received);
        vm.assume(TestAsset(address(assetPair.ct)).balanceOf(address(this)) >= repaymentAmount);

        // send caller their DS
        assetPair.ds.transfer(caller, received);
        // repay flash loan
        assetPair.ct.transfer(hook, repaymentAmount);
    }
}