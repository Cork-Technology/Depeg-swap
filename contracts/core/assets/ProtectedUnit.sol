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
import {PermitChecker} from "../../libraries/PermitChecker.sol";

struct DSData {
    address dsAddress;
    uint256 totalDeposited;
}

/**
 * @title ProtectedUnit
 * @notice This contract allows minting and dissolving ProtectedUnit tokens in exchange for two underlying assets.
 * @dev The contract uses OpenZeppelin's ERC20, ReentrancyGuardTransient,Pausable and Ownable modules.
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

    /// @notice The ERC20 token representing the PA asset.
    ERC20 public immutable PA;
    ERC20 public immutable RA;

    uint256 public dsReserve;
    uint256 public paReserve;
    uint256 public raReserve;

    Id public id;

    /// @notice The ERC20 token representing the ds asset.
    Asset internal ds;

    /// @notice Maximum supply cap for minting ProtectedUnit tokens.
    uint256 public mintCap;

    DSData[] public dsHistory;
    mapping(address => uint256) private dsIndexMap;

    /**
     * @dev Constructor that sets the DS and pa tokens and initializes the mint cap.
     * @param _moduleCore Address of the moduleCore.
     * @param _pa Address of the pa token.
     * @param _pairName Name of the ProtectedUnit pair.
     * @param _mintCap Initial mint cap for the ProtectedUnit tokens.
     */
    constructor(
        address _moduleCore,
        Id _id,
        address _pa,
        address _ra,
        string memory _pairName,
        uint256 _mintCap,
        address _config,
        address _flashSwapRouter
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
    }

    modifier autoUpdateDS() {
        _getLastDS();
        _;
    }

    modifier onlyLiquidationContract() {
        if (!CONFIG.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidator();
        }
        _;
    }

    modifier onlyValidToken(address token) {
        if (token != address(PA) && token != address(RA)) {
            revert InvalidToken();
        }
        _;
    }

    modifier onlyOwnerOrLiquidator() {
        if (msg.sender != owner() && !CONFIG.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidatorOrOwner();
        }
        _;
    }

    modifier autoSync() {
        _;
        _sync();
    }

    function _sync() internal autoUpdateDS {
        dsReserve = ds.balanceOf(address(this));
        paReserve = PA.balanceOf(address(this));
        raReserve = RA.balanceOf(address(this));
    }

    function sync() external autoUpdateDS {
        _sync();
    }

    function _fetchLatestDS() internal view returns (Asset) {
        uint256 dsId = MODULE_CORE.lastDsId(id);
        (, address dsAdd) = MODULE_CORE.swapAsset(id, dsId);

        if (dsAdd == address(0) || Asset(dsAdd).isExpired()) {
            revert NoValidDSExist();
        }

        return Asset(dsAdd);
    }

    function latestDs() external view returns (address) {
        return address(_fetchLatestDS());
    }

    function getReserves() external view returns (uint256 _dsReserves, uint256 _paReserves, uint256 _raReserves) {
        _dsReserves = dsReserve;
        _paReserves = paReserve;
        _raReserves = raReserve;
    }

    function requestLiquidationFunds(uint256 amount, address token)
        external
        onlyLiquidationContract
        onlyValidToken(token)
    {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance < amount) {
            revert InsufficientFunds();
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit LiquidationFundsRequested(msg.sender, token, amount);
    }

    function receiveFunds(uint256 amount, address token) external onlyValidToken(token) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsReceived(msg.sender, token, amount);
    }

    function useFunds(
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external autoUpdateDS onlyOwnerOrLiquidator returns (uint256 amountOut) {
        uint256 dsId = MODULE_CORE.lastDsId(id);
        IERC20(RA).safeIncreaseAllowance(address(FLASHSWAP_ROUTER), amount);

        IDsFlashSwapCore.SwapRaForDsReturn memory result =
            FLASHSWAP_ROUTER.swapRaforDs(id, dsId, amount, amountOutMin, params, offchainGuess);

        amountOut = result.amountOut;

        emit FundsUsed(msg.sender, dsId, amount, result.amountOut);
    }

    function redeemRaWithDsPa(uint256 amountPa, uint256 amountDs) external autoUpdateDS onlyOwner {
        uint256 dsId = MODULE_CORE.lastDsId(id);

        ds.approve(address(MODULE_CORE), amountDs);
        IERC20(PA).safeIncreaseAllowance(address(MODULE_CORE), amountPa);

        MODULE_CORE.redeemRaWithDsPa(id, dsId, amountPa);

        // auto pause
        _pause();

        emit RaRedeemed(msg.sender, dsId, amountPa);
    }

    function fundsAvailable(address token) external view onlyValidToken(token) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Internal function to get the latest DS address.
     * Calls moduleCore to get the latest DS id and retrieves the associated DS address.
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

    function _selfPaReserve() internal view returns (uint256) {
        return TransferHelper.tokenNativeDecimalsToFixed(paReserve, PA);
    }

    function _selfRaReserve() internal view returns (uint256) {
        return TransferHelper.tokenNativeDecimalsToFixed(raReserve, RA);
    }

    function _selfDsReserve() internal view returns (uint256) {
        return dsReserve;
    }

    function _transferDs(address _to, uint256 _amount) internal {
        IERC20(ds).safeTransfer(_to, _amount);
    }

    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of pa tokens required to mint the specified amount of ProtectedUnit tokens.
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
     * @notice Mints ProtectedUnit tokens by transferring the equivalent amount of DS and pa tokens.
     * @dev The function checks for the paused state and mint cap before minting.
     * @param amount The amount of ProtectedUnit tokens to mint.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     * @return dsAmount The amount of DS tokens used to mint ProtectedUnit tokens.
     * @return paAmount The amount of pa tokens used to mint ProtectedUnit tokens.
     */
    function mint(uint256 amount)
        external
        whenNotPaused
        nonReentrant
        autoUpdateDS
        autoSync
        returns (uint256 dsAmount, uint256 paAmount)
    {
        (dsAmount, paAmount) = __mint(msg.sender, amount);
    }

    function __mint(address minter, uint256 amount) internal returns (uint256 dsAmount, uint256 paAmount) {
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

        TransferHelper.transferFromNormalize(ds, minter, dsAmount);

        // this calculation is based on the assumption that the DS token has 18 decimals but pa can have different decimals

        TransferHelper.transferFromNormalize(PA, minter, paAmount);
        dsHistory[dsIndexMap[address(ds)]].totalDeposited += amount;

        _mint(minter, amount);

        emit Mint(minter, amount);
    }

    // if pa do not support permit, then user can still use this function with only ds permit and manual approval on the PA side
    function mint(
        address minter,
        uint256 amount,
        bytes calldata rawDsPermitSig,
        bytes calldata rawPaPermitSig,
        uint256 deadline
    ) external whenNotPaused nonReentrant autoUpdateDS autoSync returns (uint256 dsAmount, uint256 paAmount) {
        if (rawDsPermitSig.length == 0  || deadline == 0) {
            revert InvalidSignature();
        }

        (dsAmount, paAmount) = previewMint(amount);

        Signature memory sig = MinimalSignatureHelper.split(rawDsPermitSig);
        ds.permit(minter, address(this), dsAmount, deadline, sig.v, sig.r, sig.s, DS_PERMIT_MINT_TYPEHASH);

        if (rawPaPermitSig.length != 0) {
            sig = MinimalSignatureHelper.split(rawPaPermitSig);
            IERC20Permit(address(PA)).permit(minter, address(this), paAmount, deadline, sig.v, sig.r, sig.s);
        }

        (uint256 _actualDs, uint256 _actualPa) = __mint(minter, amount);

        assert(_actualDs == dsAmount);
        assert(_actualPa == paAmount);
    }

    /**
     * @notice Returns the dsAmount, paAmount and raAmount received for dissolving the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return raAmount The amount of RA tokens received for dissolving the specified amount of ProtectedUnit tokens.
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
     * @notice Burns ProtectedUnit tokens and returns the equivalent amount of DS and pa tokens.
     * @param amount The amount of ProtectedUnit tokens to burn.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts InvalidAmount if the user has insufficient ProtectedUnit balance.
     */
    function burnFrom(address account, uint256 amount)
        public
        override
        whenNotPaused
        nonReentrant
        autoUpdateDS
        autoSync
    {
        _burnHU(account, amount);
    }

    function burn(uint256 amount) public override whenNotPaused nonReentrant autoUpdateDS autoSync {
        _burnHU(msg.sender, amount);
    }

    function _burnHU(address dissolver, uint256 amount)
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

    function _burnFrom(address account, uint256 value) internal {
        if (account != msg.sender) {
            _spendAllowance(account, msg.sender, value);
        }

        _burn(account, value);
    }

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external onlyOwner {
        if (_newMintCap == mintCap) {
            revert InvalidValue();
        }
        mintCap = _newMintCap;
        emit MintCapUpdated(_newMintCap);
    }

    /**
     * @notice Pause this contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause this contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _normalize(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter) public pure returns (uint256) {
        return ProtectedUnitMath.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }

    //  Make reserves in sync with the actual balance of the contract
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
