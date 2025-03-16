// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

// TODO : support permit
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20, IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProtectedUnit} from "../../interfaces/IProtectedUnit.sol";
import {Id} from "../../libraries/Pair.sol";
import {Asset} from "./Asset.sol";
import {ProtectedUnitMath} from "./../../libraries/ProtectedUnitMath.sol";
import {CorkConfig} from "./../CorkConfig.sol";
import {IProtectedUnitLiquidation} from "./../../interfaces/IProtectedUnitLiquidation.sol";
import {IDsFlashSwapCore} from "./../../interfaces/IDsFlashSwapRouter.sol";
import {ModuleCore} from "./../ModuleCore.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Signature, MinimalSignatureHelper} from "./../../libraries/SignatureHelperLib.sol";
import {TransferHelper} from "./../../libraries/TransferHelper.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

/**
 * @notice Data structure for tracking DS token information
 * @param dsAddress The address of the DS token
 * @param totalDeposited The total amount of tokens deposited for this DS
 */
struct DSData {
    address dsAddress;
    uint256 totalDeposited;
}

/**
 * @title Protected Unit Token
 * @notice A token that represents a bundled position of multiple assets DS + PA tokens
 * @dev This contract allows users to create (mint) and redeem (burn) Protected Unit tokens
 * by depositing or withdrawing the underlying assets in the correct proportions
 * @author Cork Protocol Team
 */
contract ProtectedUnit is
    ERC20Permit,
    ReentrancyGuardTransient,
    Ownable,
    Pausable,
    IProtectedUnit,
    IProtectedUnitLiquidation,
    ERC20Burnable
{
    string public constant DS_PERMIT_MINT_TYPEHASH = "mint(uint256 amount)";

    using SafeERC20 for IERC20;

    CorkConfig public immutable CONFIG;
    IDsFlashSwapCore public immutable FLASHSWAP_ROUTER;
    ModuleCore public immutable MODULE_CORE;

    /// @notice Permit2 contract address
    IPermit2 public immutable PERMIT2;

    /**
     * @notice The ERC20 token representing the Pegged Asset (PA)
     * @dev One of the underlying assets in the Protected Unit bundle
     */
    ERC20 public immutable PA;

    /// @notice The ERC20 token representing the Redemption Asset (RA)
    ERC20 public immutable RA;

    uint256 public dsReserve;
    uint256 public paReserve;
    uint256 public raReserve;

    /**
     * @notice Unique PSM/Vault identifier for RA:PA markets in modulecore
     * @dev Used to match with corresponding market in modulecore
     */
    Id public id;

    /// @notice The ERC20 token representing the ds asset.
    Asset internal ds;

    /// @notice Maximum supply cap for minting ProtectedUnit tokens
    uint256 public mintCap;

    /// @notice Historical record of all DS tokens used by this contract
    /// @dev Used to track deposits across DS token rotations
    DSData[] public dsHistory;

    /// @notice Mapping from DS token address to its index in dsHistory array
    mapping(address => uint256) private dsIndexMap;

    /**
     * @notice Creates a new Protected Unit token contract
     * @param _moduleCore Address of the core module that manages this token
     * @param _id Unique identifier for RA:PA market in modulecore
     * @param _pa Address of the Pegged Asset token
     * @param _ra Address of the Redemption Asset token
     * @param _pairName Human-readable name for this token pair
     * @param _mintCap Maximum number of tokens that can be created
     * @param _config Address of the configuration contract
     * @param _flashSwapRouter Address of the flash swap router
     * @param _permit2 Address of the Permit2 contract
     */
    constructor(
        address _moduleCore,
        Id _id,
        address _pa,
        address _ra,
        string memory _pairName,
        uint256 _mintCap,
        address _config,
        address _flashSwapRouter,
        address _permit2
    )
        ERC20(string(abi.encodePacked("Protected Unit - ", _pairName)), string(abi.encodePacked("PU - ", _pairName)))
        ERC20Permit(string(abi.encodePacked("Protected Unit - ", _pairName)))
        Ownable(_config)
    {
        MODULE_CORE = ModuleCore(_moduleCore);
        id = _id;
        PA = ERC20(_pa);
        RA = ERC20(_ra);
        mintCap = _mintCap;
        FLASHSWAP_ROUTER = IDsFlashSwapCore(_flashSwapRouter);
        CONFIG = CorkConfig(_config);
        PERMIT2 = IPermit2(_permit2);
    }

    /**
     * @notice Ensures the latest DS token is fetched before executing the function
     * @dev Updates the internal ds token reference if necessary
     */
    modifier autoUpdateDS() {
        _getLastDS();
        _;
    }

    /**
     * @notice Restricts function access to whitelisted liquidation contracts
     * @custom:reverts OnlyLiquidator if caller is not whitelisted
     */
    modifier onlyLiquidationContract() {
        if (!CONFIG.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidator();
        }
        _;
    }

    /**
     * @notice Validates that the provided token is either PA or RA
     * @param token The token address to validate
     * @custom:reverts InvalidToken if token is neither PA nor RA
     */
    modifier onlyValidToken(address token) {
        if (token != address(PA) && token != address(RA)) {
            revert InvalidToken();
        }
        _;
    }

    /**
     * @notice Restricts function access to contract owner or liquidation contracts
     * @custom:reverts OnlyLiquidatorOrOwner if caller is not authorized
     */
    modifier onlyOwnerOrLiquidator() {
        if (msg.sender != owner() && !CONFIG.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidatorOrOwner();
        }
        _;
    }

    /// @notice Automatically synchronizes token reserves after function execution
    modifier autoSync() {
        _;
        _sync();
    }

    /**
     * @notice Updates the contract's internal record of token reserves
     * @dev Fetches the latest DS token if needed and updates all reserves
     */
    function _sync() internal autoUpdateDS {
        dsReserve = ds.balanceOf(address(this));
        paReserve = PA.balanceOf(address(this));
        raReserve = RA.balanceOf(address(this));
    }

    /// @notice Synchronizes the contract's internal record of token reserves
    function sync() external autoUpdateDS {
        _sync();
    }

    /**
     * @notice Fetches the latest valid DS token from ModuleCore
     * @dev Checks if the current DS is expired and retrieves a new one if needed
     * @return The latest valid DS Asset
     * @custom:reverts NoValidDSExist if no valid DS token exists
     */
    function _fetchLatestDS() internal view returns (Asset) {
        uint256 dsId = MODULE_CORE.lastDsId(id);
        (, address dsAdd) = MODULE_CORE.swapAsset(id, dsId);

        if (dsAdd == address(0) || Asset(dsAdd).isExpired()) {
            revert NoValidDSExist();
        }

        return Asset(dsAdd);
    }

    /**
     * @notice Returns the address of the latest valid DS token
     * @return Address of the latest valid DS token
     * @custom:reverts NoValidDSExist if no valid DS token exists
     */
    function latestDs() external view returns (address) {
        return address(_fetchLatestDS());
    }

    /**
     * @notice Gets the current reserves of all tokens held by this contract
     * @return _dsReserves Amount of DS tokens in reserve
     * @return _paReserves Amount of PA tokens in reserve
     * @return _raReserves Amount of RA tokens in reserve
     */
    function getReserves() external view returns (uint256 _dsReserves, uint256 _paReserves, uint256 _raReserves) {
        _dsReserves = dsReserve;
        _paReserves = paReserve;
        _raReserves = raReserve;
    }

    /**
     * @notice Allows the liquidator to request funds for liquidation
     * @param amount How many tokens to request
     * @param token Which token to request (must be PA or RA)
     * @custom:reverts InsufficientFunds if the contract has insufficient tokens
     * @custom:reverts OnlyLiquidator if caller is not whitelisted
     * @custom:reverts InvalidToken if token is neither PA nor RA
     * @custom:emits LiquidationFundsRequested when funds are successfully transferred
     */
    function requestLiquidationFunds(uint256 amount, address token)
        external
        onlyLiquidationContract
        onlyValidToken(token)
        autoSync
    {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance < amount) {
            revert InsufficientFunds();
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit LiquidationFundsRequested(msg.sender, token, amount);
    }

    /**
     * @notice Accepts incoming funds from liquidation or other operations
     * @dev Transfers the specified amount of the token from the sender to this contract
     * @param amount How many tokens are being received
     * @param token Which token is being received (must be PA or RA)
     * @custom:reverts InvalidToken if token is neither PA nor RA
     * @custom:emits FundsReceived when funds are successfully transferred
     */
    function receiveFunds(uint256 amount, address token) external onlyValidToken(token) autoSync {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsReceived(msg.sender, token, amount);
    }

    /**
     * @notice Uses funds to perform a flash swap.
     * @dev Increases allowance for the flash swap router and performs the swap.
     * @param amount The amount of RA tokens to be swapped.
     * @param amountOutMin The minimum amount of DS tokens expected from the swap.
     * @param params The parameters for the flash swap.
     * @param offchainGuess The offchain guess parameters for the swap.
     * @return amountOut The amount of DS tokens received from the swap.
     * @custom:reverts If the flash swap fails or returns less than amountOutMin
     * @custom:emits FundsUsed when the swap is successfully completed
     */
    function useFunds(
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external autoUpdateDS onlyOwnerOrLiquidator autoSync returns (uint256 amountOut) {
        uint256 dsId = MODULE_CORE.lastDsId(id);
        IERC20(RA).safeIncreaseAllowance(address(FLASHSWAP_ROUTER), amount);

        IDsFlashSwapCore.SwapRaForDsReturn memory result =
            FLASHSWAP_ROUTER.swapRaforDs(id, dsId, amount, amountOutMin, params, offchainGuess);

        amountOut = result.amountOut;

        emit FundsUsed(msg.sender, dsId, amount, result.amountOut);
    }

    /**
     * @notice Redeems RA tokens using DS and PA tokens.
     * @dev This function allows the owner to redeem RA tokens by providing DS and PA tokens.
     * It automatically updates DS, syncs the state, and pauses the contract after redemption.
     * @param amountPa The amount of PA tokens to be used for redemption.
     * @param amountDs The amount of DS tokens to be used for redemption.
     * @custom:reverts If redeeming fails in the module core
     * @custom:emits RaRedeemed when redemption is successful
     */
    function redeemRaWithDsPa(uint256 amountPa, uint256 amountDs) external autoUpdateDS onlyOwner autoSync {
        uint256 dsId = MODULE_CORE.lastDsId(id);

        ds.approve(address(MODULE_CORE), amountDs);
        IERC20(PA).safeIncreaseAllowance(address(MODULE_CORE), amountPa);

        MODULE_CORE.redeemRaWithDsPa(id, dsId, amountPa);

        // auto pause
        _pause();

        emit RaRedeemed(msg.sender, dsId, amountPa);
    }

    /**
     * @notice Returns the available funds of a specified token.
     * @dev This function checks the balance of the specified token in the contract.
     * @param token The address of the token to check the balance of.
     * @return The balance of the specified token in the contract.
     * @custom:reverts InvalidToken if token is neither PA nor RA
     */
    function fundsAvailable(address token) external view onlyValidToken(token) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Internal function to get the latest DS address
     * @dev Calls moduleCore to get the latest DS id and retrieves the associated DS address.
     * The reason we don't update the reserve is to avoid DDoS manipulation where user
     * could frontrun and send just 1 wei more to skew the reserve. resulting in failing transaction.
     * But since we need the address of the new DS if it's expired to transfer it correctly, we only update
     * the address here at the start of the function call, then finally update the balance after the function call
     */
    function _getLastDS() internal {
        if (address(ds) == address(0) || ds.isExpired()) {
            Asset _ds = _fetchLatestDS();

            // Check if the DS address already exists in history
            bool found = false;
            uint256 index = dsIndexMap[address(_ds)];
            if (dsHistory.length > 0 && dsHistory[index].dsAddress == address(_ds)) {
                // DS address is already at index
                ds = _ds;
                found = true;
            }

            // If not found, add new DS address to history
            if (!found) {
                ds = _ds;
                dsHistory.push(DSData({dsAddress: address(ds), totalDeposited: 0}));
                dsIndexMap[address(ds)] = dsHistory.length - 1; // Store the index
            }
        }
    }

    /// @notice Returns the PA reserve in normalized fixed point representation
    function _selfPaReserve() internal view returns (uint256) {
        return TransferHelper.tokenNativeDecimalsToFixed(paReserve, PA);
    }

    /// @notice Returns the RA reserve in normalized fixed point representation
    function _selfRaReserve() internal view returns (uint256) {
        return TransferHelper.tokenNativeDecimalsToFixed(raReserve, RA);
    }

    /// @notice Returns the DS reserve
    function _selfDsReserve() internal view returns (uint256) {
        return dsReserve;
    }

    /// @notice Transfers DS tokens to the specified address
    function _transferDs(address _to, uint256 _amount) internal {
        IERC20(ds).safeTransfer(_to, _amount);
    }

    /**
     * @notice Returns the DS and PA amounts required to mint the specified amount of ProtectedUnit tokens
     * @param amount The amount of ProtectedUnit tokens to mint
     * @return dsAmount The amount of DS tokens required
     * @return paAmount The amount of PA tokens required
     * @custom:reverts InvalidAmount if amount is zero
     * @custom:reverts MintCapExceeded if the mint cap would be exceeded
     */
    function previewMint(uint256 amount) public view returns (uint256 dsAmount, uint256 paAmount) {
        if (amount == 0) {
            revert InvalidAmount();
        }

        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        (dsAmount, paAmount) = ProtectedUnitMath.previewMint(amount, _selfPaReserve(), _selfDsReserve(), totalSupply());

        paAmount = TransferHelper.fixedToTokenNativeDecimals(paAmount, PA);
    }

    /**
     * @notice Mints ProtectedUnit tokens by transferring the equivalent amount of DS and PA tokens
     * @dev The function checks for the paused state and mint cap before minting.
     * @param amount The amount of ProtectedUnit tokens to mint
     * @return dsAmount The amount of DS tokens used
     * @return paAmount The amount of PA tokens used
     * @custom:reverts EnforcedPause if minting is currently paused
     * @custom:reverts MintCapExceeded if the mint cap is exceeded
     * @custom:reverts InvalidAmount if amount is zero
     * @custom:emits Mint when tokens are successfully minted
     */
    function mint(uint256 amount)
        external
        whenNotPaused
        nonReentrant
        autoUpdateDS
        autoSync
        returns (uint256 dsAmount, uint256 paAmount)
    {
        (dsAmount, paAmount) = __mint(msg.sender, amount, false);
    }

    /**
     * @notice Internal implementation of mint functionality
     * @dev Handles the token transfers and minting logic
     */
    function __mint(address minter, uint256 amount, bool isPermit)
        internal
        returns (uint256 dsAmount, uint256 paAmount)
    {
        if (amount == 0) {
            revert InvalidAmount();
        }

        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        {
            (dsAmount, paAmount) =
                ProtectedUnitMath.previewMint(amount, _selfPaReserve(), _selfDsReserve(), totalSupply());
            paAmount = TransferHelper.fixedToTokenNativeDecimals(paAmount, PA);
        }

        // this calculation is based on the assumption that the DS token has 18 decimals but pa can have different decimals
        if (!isPermit) {
            TransferHelper.transferFromNormalize(ds, minter, dsAmount);
            TransferHelper.transferFromNormalize(PA, minter, paAmount);
        }

        dsHistory[dsIndexMap[address(ds)]].totalDeposited += amount;

        _mint(minter, amount);

        emit Mint(minter, amount);
    }

    // if pa do not support permit, then user can still use this function with only ds permit and manual approval on the PA side
    /**
     * @notice Mints new tokens using Permit2 for gasless batch approvals
     * @dev Uses Uniswap's Permit2 protocol to approve both DS and PA tokens in a single signature
     * @param amount The amount of tokens to be minted
     * @param permitBatchData The Permit2 batch permit data for token approvals
     * @param signature The signature authorizing the permits
     * @return dsAmount The amount of DS tokens used
     * @return paAmount The amount of PA tokens used
     * @custom:reverts InvalidSignature if signature data is invalid
     * @custom:reverts EnforcedPause if minting is paused
     * @custom:emits Mint when tokens are successfully minted
     */
    function mint(
        uint256 amount,
        IPermit2.PermitBatchTransferFrom calldata permitBatchData,
        IPermit2.SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external whenNotPaused nonReentrant autoUpdateDS autoSync returns (uint256 dsAmount, uint256 paAmount) {
        if (signature.length == 0 || permitBatchData.permitted.length != 2 || transferDetails.length != 2) {
            revert InvalidSignature();
        }

        // Calculate token amounts needed for minting
        (dsAmount, paAmount) = previewMint(amount);
        if (transferDetails[0].requestedAmount < dsAmount || transferDetails[1].requestedAmount < paAmount) {
            revert InvalidSignature();
        }

        // Batch transfer tokens from user to this contract using Permit2
        PERMIT2.permitTransferFrom(permitBatchData, transferDetails, msg.sender, signature);

        // Mint the tokens to the owner
        (uint256 _actualDs, uint256 _actualPa) = __mint(msg.sender, amount, true);

        assert(_actualDs == dsAmount);
        assert(_actualPa == paAmount);
    }

    /**
     * @notice Returns the token amounts received for burning the specified amount of ProtectedUnit tokens
     * @dev Calculates proportional amounts based on current reserves and total supply
     * @param dissolver The address that will burn the tokens
     * @param amount The amount of ProtectedUnit tokens to burn
     * @return dsAmount The amount of DS tokens to receive
     * @return paAmount The amount of PA tokens to receive
     * @return raAmount The amount of RA tokens to receive
     * @custom:reverts InvalidAmount if amount is zero or exceeds balance
     */
    function previewBurn(address dissolver, uint256 amount)
        public
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount)
    {
        if (amount == 0 || amount > balanceOf(dissolver)) {
            revert InvalidAmount();
        }
        uint256 totalLiquidity = totalSupply();
        uint256 reservePa = _selfPaReserve();
        uint256 reserveDs = ds.balanceOf(address(this));
        uint256 reserveRa = _selfRaReserve();

        (paAmount, dsAmount, raAmount) =
            ProtectedUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, amount);
    }

    /**
     * @notice Burns ProtectedUnit tokens from a specific account and returns the underlying assets
     * @dev Requires approval if caller isn't the token owner
     * @param account The address from which to burn tokens
     * @param amount The amount of ProtectedUnit tokens to burn
     * @custom:reverts EnforcedPause if burning is paused
     * @custom:reverts InvalidAmount if amount is invalid
     * @custom:emits Burn when tokens are successfully burned
     */
    function burnFrom(address account, uint256 amount)
        public
        override
        whenNotPaused
        nonReentrant
        autoUpdateDS
        autoSync
    {
        _burnPU(account, amount);
    }

    /**
     * @notice Burns ProtectedUnit tokens from the caller and returns the underlying assets
     * @param amount The amount of ProtectedUnit tokens to burn
     * @custom:reverts EnforcedPause if burning is paused
     * @custom:reverts InvalidAmount if amount is invalid
     * @custom:emits Burn when tokens are successfully burned
     */
    function burn(uint256 amount) public override whenNotPaused nonReentrant autoUpdateDS autoSync {
        _burnPU(msg.sender, amount);
    }

    /**
     * @notice Internal implementation of burn functionality
     * @dev Calculates token amounts, burns ProtectedUnit tokens, and transfers underlying assets
     */
    function _burnPU(address dissolver, uint256 amount)
        internal
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount)
    {
        (dsAmount, paAmount, raAmount) = previewBurn(dissolver, amount);

        _burnFrom(dissolver, amount);

        TransferHelper.transferNormalize(PA, dissolver, paAmount);
        _transferDs(dissolver, dsAmount);
        TransferHelper.transferNormalize(RA, dissolver, raAmount);

        emit Burn(dissolver, amount, dsAmount, paAmount);
    }

    /// @notice Internal function to burn tokens from an account
    function _burnFrom(address account, uint256 value) internal {
        if (account != msg.sender) {
            _spendAllowance(account, msg.sender, value);
        }

        _burn(account, value);
    }

    /**
     * @notice Updates the cap for minting new tokens
     * @param _newMintCap The new minting cap
     * @custom:reverts InvalidValue if the mint cap isn't changed
     * @custom:reverts OnlyOwner if caller is not the owner
     * @custom:emits MintCapUpdated when the cap is successfully updated
     */
    function updateMintCap(uint256 _newMintCap) external onlyOwner {
        if (_newMintCap == mintCap) {
            revert InvalidValue();
        }
        mintCap = _newMintCap;
        emit MintCapUpdated(_newMintCap);
    }

    /**
     * @notice Pauses mint and burn operations
     * @dev Can only be called by the contract owner
     * @custom:emits Paused event (from Pausable)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses mint and burn operations
     * @dev Can only be called by the contract owner
     * @custom:emits Unpaused event (from Pausable)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _normalize(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter) public pure returns (uint256) {
        return ProtectedUnitMath.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }

    //  Make reserves in sync with the actual balance of the contract
    /**
     * @notice Transfers excess tokens from the contract to the specified address.
     * @dev Compares actual balances with recorded reserves and transfers the difference
     * @param to The address to which the excess tokens will be transferred.
     * @custom:reverts If any token transfer fails
     */
    function skim(address to) external nonReentrant {
        if (PA.balanceOf(address(this)) - paReserve > 0) {
            PA.transfer(to, PA.balanceOf(address(this)) - paReserve);
        }
        if (RA.balanceOf(address(this)) - raReserve > 0) {
            RA.transfer(to, RA.balanceOf(address(this)) - raReserve);
        }
        if (ds.balanceOf(address(this)) - dsReserve > 0) {
            ds.transfer(to, ds.balanceOf(address(this)) - dsReserve);
        }
    }
}
