// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IErrors {
    /// @notice trying to do swap/remove liquidity without sufficient liquidity
    error NotEnoughLiquidity();

    /// @notice trying to do something with a token that is not in the pool or initializing token that doesn't have expiry
    error InvalidToken();

    /// @notice trying to change fee to a value higher than MAX_FEE that is 100e18
    error InvalidFee();

    /// @notice trying to add liquidity through the pool manager
    error DisableNativeLiquidityModification();

    /// @notice trying to initialize the pool more than once
    error AlreadyInitialized();

    /// @notice trying to swap/remove liquidity from non-initialized pool
    error NotInitialized();

    /// @notice trying to swap with invalid amount or adding liquidity without proportion, e.g 0
    error InvalidAmount();

    /// @notice somehow the sender is not set in the forwarder contract when using hook swap function
    error NoSender();

    /// @notice only self call is allowed when forwarding callback in hook forwarder
    error OnlySelfCall();

    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    /// @notice thrown when Permit is not supported in Given ERC20 contract
    error PermitNotSupported();

    /// @notice thrown when the caller is not the module core
    error NotModuleCore();

    /// @notice thrown when the caller is not Config contract
    error NotConfig();

    /// @notice thrown when the swap somehow got into rollover period, but the rollover period is not active
    error RolloverNotActive();

    error NotDefaultAdmin();

    error ApproxExhausted();

    error InvalidParams();

    /// @notice Error indicating the mint cap has been exceeded.
    error MintCapExceeded();

    /// @notice Error indicating an invalid value was provided.
    error InvalidValue();

    /// @notice Thrown when the DS given when minting HU isn't proportional
    error InsufficientDsAmount();

    /// @notice Thrown when the PA given when minting HU isn't proportional
    error InsufficientPaAmount();

    error NoValidDSExist();

    error OnlyLiquidatorOrOwner();

    error InsufficientFunds();

    error OnlyDissolverOrHURouterAllowed();

    error NotYetClaimable(uint256 claimableAt, uint256 blockTimestamp);

    error NotOwner(address owner, address msgSender);

    error OnlyVault();

    /// @notice thrown when the user tries to repurchase more than the available PA + DSliquidity
    /// @param available the amount of available PA + DS
    /// @param requested the amount of PA + DS user will receive
    error InsufficientLiquidity(uint256 available, uint256 requested);

    /// @notice Error indicating provided signature is invalid
    error InvalidSignature();

    /// @notice limit too long when getting deployed assets
    /// @param max Max Allowed Length
    /// @param received Length of current given parameter
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice error when trying to deploying a swap asset of a non existent pair
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param pa Address of PA(Pegged Asset) contract
    error NotExist(address ra, address pa);

    /// @notice only flash swap router is allowed to call this function
    error OnlyFlashSwapRouterAllowed();

    /// @notice only config contract is allowed to call this function
    error OnlyConfigAllowed();

    /// @notice Trying to issue an expired asset
    error Expired();

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

    /// @notice thrown when blacklisted liquidation contract tries to request funds from the vault
    error OnlyWhiteListed();

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    /// @notice inssuficient balance to perform expiry redeem(e.g requesting 5 LV to redeem but trying to redeem 10)
    error InsufficientBalance(address caller, uint256 requested, uint256 balance);

    /// @notice insufficient output amount, e.g trying to redeem 100 LV whcih you expect 100 RA but only received 50 RA
    error InsufficientOutputAmount(uint256 amountOutMin, uint256 received);

    /// @notice vault does not have sufficient funds to do something

    /// @notice no sane root is found when calculating value for buying DS
    error InvalidS();

    /// @notice no sane upper interval is found when trying to calculate value for buying DS
    error NoSignChange();

    /// @notice bisection method fail to converge after max iterations(256)
    error NoConverge();

    /// @notice invalid parameter
    error InvalidParam();

    /// @notice thrown when Reserve is Zero
    error ZeroReserve();

    /// @notice thrown when Input amount is not sufficient
    error InsufficientInputAmount();

    /// @notice thrown when not having sufficient Liquidity
    error InsufficientLiquidityForSwap();

    /// @notice thrown when Output amount is not sufficient
    error InsufficientOutputAmountForSwap();

    /// @notice thrown when the number is too big
    error TooBig();

    error NoLowerBound();

    error HedgeUnitExists();

    error InvalidPairId();

    // This error occurs when user passes invalid input to the function.
    error InvalidInput();

    error CallerNotFactory();

    error HedgeUnitNotExists();

    /// @notice thrown when the internal reference id is invalid
    error InalidRefId();

    /// @notice thrown when the caller is not the hook trampoline
    error OnlyTrampoline();

    /// @notice thron when the caller is not the liquidator
    error OnlyLiquidator();
}