// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO : more detailing regardings event parameters needed
interface IPool {
    error NativeTransferFailed();

    error ERC20TransferFailed();

    error NotEnoughLiquidity();

    /// @notice Emitted when a stability pool issues a new stability pool token (`pDS`)
    event Issued(uint256 indexed id, address indexed issuer, uint256 expiry);

    /// @notice Emitted when the pool base asset reaches the target threshold, indicating that no further deposit should be made into the AMM until the threshold is breached
    event TargetThresholdReached();

    /// @notice Emitted when the pool base asset reaches the liquidation threshold, indicating that the pool needs to withdraw liquidity from the AMM
    event LiquidationThresholdReached();

    /// @notice Emitted after every withdrawal request, indicating the user's address, `pdsId`, and withdrawal ID
    event WithdrawRequested(address indexed userAddress, uint256 indexed pdsId, uint256 withdrawalId);

    /// @notice Emitted after every reset of the withdrawal queue
    event WithdrawQueueResetted(uint256 time);

    /// @notice Emitted after every processed withdrawal, indicating the user's address, withdrawal ID, and time
    event WithdrawalProcessed(address indexed userAddress, uint256 indexed withdrawalId, uint256 time);

    /// @notice Emitted after a depeg swap-based redemption, indicating that a swap has been redeemed successfully
    event SwapRedeemed();

    /// @notice Emitted after an early withdrawal of pool shares, indicating that an early withdrawal has been completed successfully
    event EarlyWithdrawal(uint256 time, address indexed userAddress);

    /// return current rate with 1e18 = 1% representation (i.e 18 decimals)
    /// base asset = bA
    /// total shares = tS
    /// rate = bA / tS
    function exchangeRate() external view returns (uint256 rate);

    /// deposit a certain amount of asset into a particular pool
    function deposit(uint256 pdsId, uint256 amount) external;

    /// this returns the pegged asset address by a particular pool
    function peggedAssetInfo(
        uint256 pdsId
    ) external view returns (address assetAddress, uint8 assetDecimals);

    /// this returns the base asset address by a particular pool
    function baseAssetInfo(
        uint256 pdsId
    ) external view returns (address assetAddress, uint8 assetDecimals);

    /// preview a deposit action with current exchange rate,
    /// returns the amount of shares(share pool token) that user will receive
    function previewDeposit(
        uint256 pdsId,
        uint256 amount
    ) external view returns (uint256 shares);

    /// simulate a pds redeem.
    /// returns how much base asset the user would receive
    function previewRedeemWithPds(
        uint256 pdsId,
        uint256 amount
    ) external view returns (uint256 assets);

    /// redeem a base asset using pds
    function redeemWithPds(uint256 pdsId, uint256 amount) external;

    /// return the number of redeemed
    /// pds managed by a particular pool
    function redeemed(uint256 pdsId) external view returns (uint256 amount);

    /// request a withdrawal with ALL of the user pool share token balance.
    /// the call MAY revert if :
    /// - the user does not have a pool share token
    /// will emit an event containing users withdrawal id
    function requestWithdrawal() external;

    /// return the claimable status of a certain withdrawal id.
    /// the function MAY revert if :
    /// - the user already claim their rewards using this withdrawal id
    /// - the withdrawal id could not be found
    /// - there's not enough liquidity present in the pool to perfrom withdrawal
    /// - the withdrawal queue has been resetted, hence the id could not be found
    /// - the withdrawal period hasn't started
    /// - the user does not have a pool share token they previously have (this could-
    /// happen if the user make an early redemption AFTER requesting an expiry withdrawal).
    function isClaimable(uint256 id) external view returns (bool);

    /// return the next depeg swap expiry
    function nextExpiry() external view returns (uint256);

    /// return the the timeframe of withdrawal
    /// starting from the next depeg swap expiry in seconds
    function withdrawalPeriod() external view returns (uint256);

    /// claim the requested funds
    function claimWithdrawal(uint256 id) external;

    // request an early withdrawal with all pool share token.
    // will emit EarlyWithdrawal(time, address) if successfull
    // the call MAY revery in the case of :
    // - user does not have enough pds to cover their withdrawal (equal to all pool-
    // share token balance that user have associated with a given pool).
    function earlyWithdrawal(uint256 pdsId) external;

    // returns the fee in the form of % (e.g 3% would be 3e18)
    function earlyWithdrawalFee() external;

    // simulate a early withdrawal with additional fee applied
    function previewEarlyWithdrawal(
        uint256 pdsId
    ) external view returns (uint256 assets);

    /// return current liquidation threshold
    function liquidationThreshold() external view returns (uint256);

    /// return current target threshold
    function targetThreshold() external view returns (uint256);

    /// return current deposit threshold
    function depositThreshold() external view returns (uint256);
}
