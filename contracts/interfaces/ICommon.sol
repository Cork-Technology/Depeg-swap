// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Id} from "../libraries/Pair.sol";

/**
 * @title ICommon Interface
 * @author Cork Team
 * @notice Common Interface which provides common errors, events and functions
 */
interface ICommon {
    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    /// @notice only flash swap router is allowed to call this function
    error OnlyFlashSwapRouterAllowed();

    /// @notice only config contract is allowed to call this function
    error OnlyConfigAllowed();

    /// @notice module is not initialized, i.e thrown when interacting with uninitialized module
    error Uninitializedlized();

    /// @notice module is already initialized, i.e thrown when trying to reinitialize a module
    error AlreadyInitialized();

    /// @notice invalid asset, thrown when trying to do something with an asset not deployed with asset factory
    /// @param asset Address of given Asset contract
    error InvalidAsset(address asset);

    /// @notice PSM Deposit is paused, i.e thrown when deposit is paused for PSM
    error PSMDepositPaused();

    /// @notice PSM Withdrawal is paused, i.e thrown when withdrawal is paused for PSM
    error PSMWithdrawalPaused();

    /// @notice PSM Repurchase is paused, i.e thrown when repurchase is paused for PSM
    error PSMRepurchasePaused();

    /// @notice LV Deposit is paused, i.e thrown when deposit is paused for LV
    error LVDepositPaused();

    /// @notice LV Withdrawal is paused, i.e thrown when withdrawal is paused for LV
    error LVWithdrawalPaused();

    /// @notice When transaction is mutex locked for ensuring non-reentrancy
    error StateLocked();

    /// @notice Thrown when user deposit with 0 amount
    error ZeroDeposit();

    /// @notice Thrown this error when fees are more than 5%
    error InvalidFees();

    /// @notice thrown when trying to update rate with invalid rate
    error InvalidRate();
    
    /// @notice Revert when Signature is valid or signature deadline is incorrect
    error InvalidSignature();

    /// @notice Emitted when a new LV and PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    /// @param lv The address of the LV
    /// @param expiry The expiry interval of the DS
    event InitializedModuleCore(Id indexed id, address indexed pa, address indexed ra, address lv, uint256 expiry);

    /// @notice Emitted when a new DS is issued for a given PSM
    /// @param Id The PSM id
    /// @param dsId The DS id
    /// @param expiry The expiry of the DS
    /// @param ds The address of the DS token
    /// @param ct The address of the CT token
    /// @param raCtUniPairId The id of the uniswap-v4 pair between RA and CT
    event Issued(
        Id indexed Id, uint256 indexed dsId, uint256 indexed expiry, address ds, address ct, bytes32 raCtUniPairId
    );

    /**
     * @notice Get the last DS id issued for a given module, the returned DS doesn't guarantee to be active
     * @param id The current module id
     * @return dsId The current effective DS id
     *
     */
    function lastDsId(Id id) external view returns (uint256 dsId);

    /**
     * @notice returns the address of the underlying RA and PA token
     * @param id the id of PSM
     * @return ra address of the underlying RA token
     * @return pa address of the underlying PA token
     */
    function underlyingAsset(Id id) external view returns (address ra, address pa);

    /**
     * @notice returns the address of CT and DS associated with a certain DS id
     * @param id the id of PSM
     * @param dsId the DS id
     * @return ct address of the CT token
     * @return ds address of the DS token
     */
    function swapAsset(Id id, uint256 dsId) external view returns (address ct, address ds);

    function getId(address pa, address ra, uint256 expiryInterva) external pure returns (Id id);
}
