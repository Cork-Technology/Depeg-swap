// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Id} from "../libraries/Pair.sol";
import {IDsFlashSwapCore} from "../interfaces/IDsFlashSwapRouter.sol";
import {ModuleCore} from "./ModuleCore.sol";
import {IVault} from "./../interfaces/IVault.sol";
import {CorkHook} from "Cork-Hook/CorkHook.sol";
import {MarketSnapshot} from "Cork-Hook/lib/MarketSnapshot.sol";
import {ProtectedUnitFactory} from "./assets/ProtectedUnitFactory.sol";
import {ProtectedUnit} from "./assets/ProtectedUnit.sol";
import {ExchangeRateProvider} from "./ExchangeRateProvider.sol";

/**
 * @title Config Contract
 * @author Cork Team
 * @notice Config contract for managing pairs and configurations of Cork protocol
 */
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant RATE_UPDATERS_ROLE = keccak256("RATE_UPDATERS_ROLE");
    bytes32 public constant BASE_LIQUIDATOR_ROLE = keccak256("BASE_LIQUIDATOR_ROLE");

    ModuleCore public moduleCore;
    IDsFlashSwapCore public flashSwapRouter;
    CorkHook public hook;
    ProtectedUnitFactory public protectedUnitFactory;
    ExchangeRateProvider public defaultExchangeRateProvider;
    // Cork Protocol's treasury address. Other Protocol component should fetch this address directly from the config contract
    // instead of storing it themselves, since it'll be hard to update the treasury address in all the components if it changes vs updating it in the config contract once
    address public treasury;

    uint256 public rolloverPeriodInBlocks = 480;

    uint256 public defaultDecayDiscountRateInDays = 0;

    // this essentially means deposit will not be allowed if the NAV of the pair is below this threshold
    // the nav is updated every vault deposit
    uint256 public defaultNavThreshold = 90 ether;

    uint256 public constant WHITELIST_TIME_DELAY = 7 days;

    /// @notice liquidation address => timestamp when liquidation is allowed
    mapping(address => uint256) internal liquidationWhitelist;

    /// @notice thrown when caller is not manager/Admin of Cork Protocol
    error CallerNotManager();

    /// @notice thrown when passed Invalid/Zero Address
    error InvalidAddress();

    /// @notice Emitted when a moduleCore variable set
    /// @param moduleCore Address of Modulecore contract
    event ModuleCoreSet(address moduleCore);

    /// @notice Emitted when a flashSwapRouter variable set
    /// @param flashSwapRouter Address of flashSwapRouter contract
    event FlashSwapCoreSet(address flashSwapRouter);

    /// @notice Emitted when a hook variable set
    /// @param hook Address of hook contract
    event HookSet(address hook);

    /// @notice Emitted when a protectedUnitFactory variable set
    /// @param protectedUnitFactory Address of protectedUnitFactory contract
    event ProtectedUnitFactorySet(address protectedUnitFactory);

    /// @notice Emitted when a treasury is set
    /// @param treasury Address of treasury contract/address
    event TreasurySet(address treasury);

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    modifier onlyUpdaterOrManager() {
        if (!hasRole(RATE_UPDATERS_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    constructor(address adminAdd, address managerAdd) {
        if (adminAdd == address(0) || managerAdd == address(0)) {
            revert InvalidAddress();
        }

        defaultExchangeRateProvider = new ExchangeRateProvider(address(this));

        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RATE_UPDATERS_ROLE, MANAGER_ROLE);
        _setRoleAdmin(BASE_LIQUIDATOR_ROLE, MANAGER_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, adminAdd);
        _grantRole(MANAGER_ROLE, managerAdd);
    }

    function updateDecayDiscountRateInDays(uint256 newDiscountRateInDays) external onlyManager {
        defaultDecayDiscountRateInDays = newDiscountRateInDays;
    }

    function updateRolloverPeriodInBlocks(uint256 newRolloverPeriodInBlocks) external onlyManager {
        rolloverPeriodInBlocks = newRolloverPeriodInBlocks;
    }

    function updateDefaultNavThreshold(uint256 newNavThreshold) external onlyManager {
        defaultNavThreshold = newNavThreshold;
    }

    function updateNavThreshold(Id id, uint256 newNavThreshold) external onlyManager {
        moduleCore.updateVaultNavThreshold(id, newNavThreshold);
    }

    function _computeLiquidatorRoleHash(address account) public view returns (bytes32) {
        return keccak256(abi.encodePacked(BASE_LIQUIDATOR_ROLE, account));
    }

    // This will be only used in case of emergency to change the manager of the different roles if any of the manager is compromised
    function setRoleAdmin(bytes32 role, bytes32 newAdminRole) external onlyRole(getRoleAdmin(role)) {
        _setRoleAdmin(role, newAdminRole);
    }

    function grantRole(bytes32 role, address account) public override onlyManager {
        _grantRole(role, account);
    }

    function transferAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    }

    function isTrustedLiquidationExecutor(address liquidationContract, address user) external view returns (bool) {
        return hasRole(_computeLiquidatorRoleHash(liquidationContract), user);
    }

    function grantLiquidatorRole(address liquidationContract, address account) external onlyManager {
        _grantRole(_computeLiquidatorRoleHash(liquidationContract), account);
    }

    function revokeLiquidatorRole(address liquidationContract, address account) external onlyManager {
        _revokeRole(_computeLiquidatorRoleHash(liquidationContract), account);
    }

    function isLiquidationWhitelisted(address liquidationAddress) external view returns (bool) {
        return
            liquidationWhitelist[liquidationAddress] <= block.timestamp && liquidationWhitelist[liquidationAddress] != 0;
    }

    function blacklist(address liquidationAddress) external onlyManager {
        delete liquidationWhitelist[liquidationAddress];
    }

    function whitelist(address liquidationAddress) external onlyManager {
        liquidationWhitelist[liquidationAddress] = block.timestamp + WHITELIST_TIME_DELAY;
    }

    /**
     * @dev Sets new ModuleCore contract address
     * @param _moduleCore new moduleCore contract address
     */
    function setModuleCore(address _moduleCore) external onlyManager {
        if (_moduleCore == address(0)) {
            revert InvalidAddress();
        }
        moduleCore = ModuleCore(_moduleCore);
        emit ModuleCoreSet(_moduleCore);
    }

    function setFlashSwapCore(address _flashSwapRouter) external onlyManager {
        if (_flashSwapRouter == address(0)) {
            revert InvalidAddress();
        }
        flashSwapRouter = IDsFlashSwapCore(_flashSwapRouter);
        emit FlashSwapCoreSet(_flashSwapRouter);
    }

    function setHook(address _hook) external onlyManager {
        if (_hook == address(0)) {
            revert InvalidAddress();
        }
        hook = CorkHook(_hook);
        emit HookSet(_hook);
    }

    function setProtectedUnitFactory(address _protectedUnitFactory) external onlyManager {
        if (_protectedUnitFactory == address(0)) {
            revert InvalidAddress();
        }
        protectedUnitFactory = ProtectedUnitFactory(_protectedUnitFactory);
        emit ProtectedUnitFactorySet(_protectedUnitFactory);
    }

    function setTreasury(address _treasury) external onlyManager {
        if (_treasury == address(0)) {
            revert InvalidAddress();
        }
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    function updateAmmBaseFeePercentage(Id id, uint256 newBaseFeePercentage) external onlyManager {
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, moduleCore.lastDsId(id));
        hook.updateBaseFeePercentage(ra, ct, newBaseFeePercentage);
    }

    function updateAmmTreasurySplitPercentage(Id id, uint256 newTreasurySplitPercentage) external onlyManager {
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, moduleCore.lastDsId(id));
        hook.updateTreasurySplitPercentage(ra, ct, newTreasurySplitPercentage);
    }

    function updatePsmBaseRedemptionFeeTreasurySplitPercentage(Id id, uint256 percentage) external onlyManager {
        moduleCore.updatePsmBaseRedemptionFeeTreasurySplitPercentage(id, percentage);
    }

    function updatePsmRepurchaseFeeTreasurySplitPercentage(Id id, uint256 percentage) external onlyManager {
        moduleCore.updatePsmRepurchaseFeeTreasurySplitPercentage(id, percentage);
    }

    function updatePsmRepurchaseFeePercentage(Id id, uint256 percentage) external onlyManager {
        moduleCore.updatePsmRepurchaseFeePercentage(id, percentage);
    }

    function setWithdrawalContract(address _withdrawalContract) external onlyManager {
        moduleCore.setWithdrawalContract(_withdrawalContract);
    }

    function updateRouterDsExtraFee(Id id, uint256 newPercentage) external onlyManager {
        flashSwapRouter.updateDsExtraFeePercentage(id, newPercentage);
    }

    function updateDsExtraFeeTreasurySplitPercentage(Id id, uint256 newPercentage) external onlyManager {
        flashSwapRouter.updateDsExtraFeeTreasurySplitPercentage(id, newPercentage);
    }

    /**
     * @dev Initialize Module Core
     * @param pa Address of PA
     * @param ra Address of RA
     * @param initialArp initial price of DS
     */
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external {
        moduleCore.initializeModuleCore(pa, ra, initialArp, expiryInterval, exchangeRateProvider);

        // auto assign nav threshold
        Id id = moduleCore.getId(pa, ra, initialArp, expiryInterval, exchangeRateProvider);
    }

    /**
     * @dev Issues new assets, will auto assign amm fees from the previous issuance
     * for first issuance, separate transaction must be made to set the fees in the AMM
     */
    function issueNewDs(Id id, uint256 ammLiquidationDeadline) external whenNotPaused {
        moduleCore.issueNewDs(id, defaultDecayDiscountRateInDays, rolloverPeriodInBlocks, ammLiquidationDeadline);

        _autoAssignFees(id);
        _autoAssignTreasurySplitPercentage(id);
    }

    function _autoAssignFees(Id id) internal {
        uint256 currentDsId = moduleCore.lastDsId(id);
        uint256 prevDsId = currentDsId - 1;

        // first issuance, no AMM fees to assign
        if (prevDsId == 0) {
            return;
        }

        // get previous issuance's assets
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, prevDsId);

        // get fees from previous issuance, we won't revert here since the fees can be assigned manually
        // if for some reason the previous issuance AMM is not created for some reason(no LV deposits)
        // slither-disable-next-line uninitialized-local
        uint256 prevBaseFee;

        try hook.getFee(ra, ct) returns (uint256 baseFee, uint256) {
            prevBaseFee = baseFee;
        } catch {
            return;
        }

        // assign fees to current issuance
        (ct,) = moduleCore.swapAsset(id, currentDsId);

        // we don't revert here since an edge case would occur where the Lv token circulation is 0 but the issuance continues
        // and in that case the AMM would not have been created yet. This is a rare edge case and the fees can be assigned manually in such cases
        // solhint-disable-next-line no-empty-blocks
        try hook.updateBaseFeePercentage(ra, ct, prevBaseFee) {} catch {}
    }

    function _autoAssignTreasurySplitPercentage(Id id) internal {
        uint256 currentDsId = moduleCore.lastDsId(id);
        uint256 prevDsId = currentDsId - 1;

        // first issuance, no AMM fees to assign
        if (prevDsId == 0) {
            return;
        }

        // get previous issuance's assets
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, prevDsId);

        // get fees from previous issuance, we won't revert here since the fees can be assigned manually
        // if for some reason the previous issuance AMM is not created for some reason(no LV deposits)
        // slither-disable-next-line uninitialized-local
        uint256 prevCtSplit;

        try hook.getMarketSnapshot(ra, ct) returns (MarketSnapshot memory snapshot) {
            prevCtSplit = snapshot.treasuryFeePercentage;
        } catch {
            return;
        }

        (ct,) = moduleCore.swapAsset(id, currentDsId);

        // we don't revert here since an edge case would occur where the Lv token circulation is 0 but the issuance continues
        // and in that case the AMM would not have been created yet. This is a rare edge case and the fees can be assigned manually in such cases
        // solhint-disable-next-line no-empty-blocks
        try hook.updateTreasurySplitPercentage(ra, ct, prevCtSplit) {} catch {}
    }

    /**
     * @notice Updates fee rates for psm repurchase
     * @param id id of PSM
     * @param newRepurchaseFeePercentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external onlyManager {
        moduleCore.updateRepurchaseFeeRate(id, newRepurchaseFeePercentage);
    }

    /**
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(Id id, bool isPSMDepositPaused) external onlyManager {
        moduleCore.updatePsmDepositsStatus(id, isPSMDepositPaused);
    }

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(Id id, bool isPSMWithdrawalPaused) external onlyManager {
        moduleCore.updatePsmWithdrawalsStatus(id, isPSMWithdrawalPaused);
    }

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(Id id, bool isPSMRepurchasePaused) external onlyManager {
        moduleCore.updatePsmRepurchasesStatus(id, isPSMRepurchasePaused);
    }

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(Id id, bool isLVDepositPaused) external onlyManager {
        moduleCore.updateLvDepositsStatus(id, isLVDepositPaused);
    }

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(Id id, bool isLVWithdrawalPaused) external onlyManager {
        moduleCore.updateLvWithdrawalsStatus(id, isLVWithdrawalPaused);
    }

    /**
     * @notice Updates base redemption fee percentage
     * @param newPsmBaseRedemptionFeePercentage new value of fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage)
        external
        onlyManager
    {
        moduleCore.updatePsmBaseRedemptionFeePercentage(id, newPsmBaseRedemptionFeePercentage);
    }

    function updateFlashSwapRouterDiscountInDays(Id id, uint256 newDiscountInDays) external onlyManager {
        flashSwapRouter.updateDiscountRateInDdays(id, newDiscountInDays);
    }

    function updateRouterGradualSaleStatus(Id id, bool status) external onlyManager {
        flashSwapRouter.updateGradualSaleStatus(id, status);
    }

    function updateLvStrategyCtSplitPercentage(Id id, uint256 newCtSplitPercentage) external onlyManager {
        IVault(address(moduleCore)).updateCtHeldPercentage(id, newCtSplitPercentage);
    }

    function updateReserveSellPressurePercentage(Id id, uint256 newSellPressurePercentage) external onlyManager {
        flashSwapRouter.updateReserveSellPressurePercentage(id, newSellPressurePercentage);
    }

    function updatePsmRate(Id id, uint256 newRate) external onlyUpdaterOrManager {
        // we update the rate in our provider regardless it's up or down. won't affect other market's rates that doesn't use this provider
        defaultExchangeRateProvider.setRate(id, newRate);
    }

    function useVaultTradeExecutionResultFunds(Id id) external onlyManager {
        moduleCore.useTradeExecutionResultFunds(id);
    }

    function updateProtectedUnitMintCap(address protectedUnit, uint256 newMintCap) external onlyManager {
        ProtectedUnit(protectedUnit).updateMintCap(newMintCap);
    }

    function deployProtectedUnit(Id id, address pa, address ra, string calldata pairName, uint256 mintCap)
        external
        onlyManager
        returns (address)
    {
        return protectedUnitFactory.deployProtectedUnit(id, pa, ra, pairName, mintCap);
    }

    function deRegisterProtectedUnit(Id id) external onlyManager {
        protectedUnitFactory.deRegisterProtectedUnit(id);
    }

    function pauseProtectedUnit(address protectedUnit) external onlyManager {
        ProtectedUnit(protectedUnit).pause();
    }

    function pauseProtectedUnitMinting(address protectedUnit) external onlyManager {
        ProtectedUnit(protectedUnit).pause();
    }

    function resumeProtectedUnitMinting(address protectedUnit) external onlyManager {
        ProtectedUnit(protectedUnit).unpause();
    }

    function redeemRaWithDsPaWithProtectedUnit(address protectedUnit, uint256 amount, uint256 amountDS)
        external
        onlyManager
    {
        ProtectedUnit(protectedUnit).redeemRaWithDsPa(amount, amountDS);
    }

    function buyDsFromProtectedUnit(
        address protectedUnit,
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external onlyManager returns (uint256 amountOut) {
        amountOut = ProtectedUnit(protectedUnit).useFunds(amount, amountOutMin, params, offchainGuess);
    }

    /**
     * @notice Pause this contract
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @notice Unpause this contract
     */
    function unpause() external onlyManager {
        _unpause();
    }
}
