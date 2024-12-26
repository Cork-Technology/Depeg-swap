pragma solidity ^0.8.24;

// TODO : support permit
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20, IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IHedgeUnit} from "../../interfaces/IHedgeUnit.sol";
import {ICommon} from "../../interfaces/ICommon.sol";
import {ILiquidator} from "../../interfaces/ILiquidator.sol";
import {Id} from "../../libraries/Pair.sol";
import {Asset} from "./Asset.sol";
import {HedgeUnitMath} from "./../../libraries/HedgeUnitMath.sol";
import {CorkConfig} from "./../CorkConfig.sol";
import {IHedgeUnitLiquidation} from "./../../interfaces/IHedgeUnitLiquidation.sol";
import {IDsFlashSwapCore} from "./../../interfaces/IDsFlashSwapRouter.sol";
import {ModuleCore} from "./../ModuleCore.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./../../libraries/SignatureHelperLib.sol";
import "./../../libraries/DepegSwapLib.sol";
import "./../../libraries/TransferHelper.sol";
import {PermitChecker} from "../../libraries/PermitChecker.sol";

struct DSData {
    address dsAddress;
    uint256 totalDeposited;
}

/**
 * @title HedgeUnit
 * @notice This contract allows minting and dissolving HedgeUnit tokens in exchange for two underlying assets.
 * @dev The contract uses OpenZeppelin's ERC20, ReentrancyGuard,Pausable and Ownable modules.
 */
contract HedgeUnit is ERC20Permit, ReentrancyGuard, Ownable, Pausable, IHedgeUnit, IHedgeUnitLiquidation {
    using SafeERC20 for IERC20;

    uint8 internal constant TARGET_DECIMALS = 18;

    ModuleCore public moduleCore;
    CorkConfig public config;
    IDsFlashSwapCore public flashSwapRouter;
    Id public id;

    /// @notice The ERC20 token representing the pa asset.
    ERC20 public pa;
    ERC20 public ra;

    /// @notice The ERC20 token representing the ds asset.
    Asset public ds;

    /// @notice Maximum supply cap for minting HedgeUnit tokens.
    uint256 public mintCap;

    DSData[] public dsHistory;
    mapping(address => uint256) private dsIndexMap;

    /**
     * @dev Constructor that sets the DS and pa tokens and initializes the mint cap.
     * @param _moduleCore Address of the moduleCore.
     * @param _pa Address of the pa token.
     * @param _pairName Name of the HedgeUnit pair.
     * @param _mintCap Initial mint cap for the HedgeUnit tokens.
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
        ERC20(string(abi.encodePacked("Hedge Unit - ", _pairName)), string(abi.encodePacked("HU - ", _pairName)))
        ERC20Permit(string(abi.encodePacked("Hedge Unit - ", _pairName)))
        Ownable(_config)
    {
        moduleCore = ModuleCore(_moduleCore);
        id = _id;
        pa = ERC20(_pa);
        ra = ERC20(_ra);
        mintCap = _mintCap;
        flashSwapRouter = IDsFlashSwapCore(_flashSwapRouter);
        config = CorkConfig(_config);
    }

    modifier autoUpdateDS() {
        _getLastDS();
        _;
    }

    modifier onlyLiquidationContract() {
        if (!config.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidator();
        }
        _;
    }

    modifier onlyValidToken(address token) {
        if (token != address(pa) && token != address(ra)) {
            revert InvalidToken();
        }
        _;
    }

    modifier onlyOwnerOrLiquidator() {
        if (msg.sender != owner() && !config.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidatorOrOwner();
        }
        _;
    }

    function _fetchLatestDS() internal view returns (Asset) {
        uint256 dsId = moduleCore.lastDsId(id);
        (, address dsAdd) = moduleCore.swapAsset(id, dsId);

        if (dsAdd == address(0) || Asset(dsAdd).isExpired()) {
            revert NoValidDSExist();
        }

        return Asset(dsAdd);
    }

    function getReserves() external view returns (uint256 dsReserves, uint256 paReserves, uint256 raReserves) {
        Asset _ds = _fetchLatestDS();

        dsReserves = _ds.balanceOf(address(this));
        paReserves = pa.balanceOf(address(this));
        raReserves = ra.balanceOf(address(this));
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

    function useFunds(uint256 amount, uint256 amountOutMin, IDsFlashSwapCore.BuyAprroxParams calldata params)
        external
        autoUpdateDS
        onlyOwnerOrLiquidator
        returns (uint256 amountOut)
    {
        uint256 dsId = moduleCore.lastDsId(id);

        ra.approve(address(flashSwapRouter), amount);

        amountOut = flashSwapRouter.swapRaforDs(id, dsId, amount, amountOutMin, params);

        emit FundsUsed(msg.sender, dsId, amount, amountOut);
    }

    function redeemRaWithDsPa(uint256 amount, uint256 amountDs) external autoUpdateDS onlyOwner {
        uint256 dsId = moduleCore.lastDsId(id);

        ds.approve(address(moduleCore), amountDs);
        pa.approve(address(moduleCore), amount);

        moduleCore.redeemRaWithDs(id, dsId, amount);

        // auto pause
        _pause();

        emit RaRedeemed(msg.sender, dsId, amount);
    }

    function fundsAvailable(address token) external view onlyValidToken(token) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Internal function to get the latest DS address.
     * Calls moduleCore to get the latest DS id and retrieves the associated DS address.
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
        return TransferHelper.tokenNativeDecimalsToFixed(pa.balanceOf(address(this)), pa);
    }

    function _selfRaReserve() internal view returns (uint256) {
        return TransferHelper.tokenNativeDecimalsToFixed(ra.balanceOf(address(this)), ra);
    }

    function _transferDs(address _to, uint256 _amount) internal {
        IERC20(ds).safeTransfer(_to, _amount);
    }

    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of HedgeUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of HedgeUnit tokens.
     * @return paAmount The amount of pa tokens required to mint the specified amount of HedgeUnit tokens.
     */
    function previewMint(uint256 amount) public view returns (uint256 dsAmount, uint256 paAmount) {
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        Asset _ds = _fetchLatestDS();

        uint256 paReserve = _selfPaReserve();

        (dsAmount, paAmount) = HedgeUnitMath.previewMint(amount, paReserve, _ds.balanceOf(address(this)), totalSupply());

        paAmount = TransferHelper.fixedToTokenNativeDecimals(paAmount, pa);
    }

    /**
     * @notice Mints HedgeUnit tokens by transferring the equivalent amount of DS and pa tokens.
     * @dev The function checks for the paused state and mint cap before minting.
     * @param amount The amount of HedgeUnit tokens to mint.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     * @return dsAmount The amount of DS tokens used to mint HedgeUnit tokens.
     * @return paAmount The amount of pa tokens used to mint HedgeUnit tokens.
     */
    function mint(uint256 amount)
        external
        whenNotPaused
        nonReentrant
        autoUpdateDS
        returns (uint256 dsAmount, uint256 paAmount)
    {
        (dsAmount, paAmount) = __mint(msg.sender, amount);
    }

    function __mint(address minter, uint256 amount) internal returns (uint256 dsAmount, uint256 paAmount) {
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        {
            uint256 paReserve = _selfPaReserve();

            (dsAmount, paAmount) =
                HedgeUnitMath.previewMint(amount, paReserve, ds.balanceOf(address(this)), totalSupply());

            paAmount = TransferHelper.fixedToTokenNativeDecimals(paAmount, pa);
        }

        TransferHelper.transferFromNormalize(ds, minter, dsAmount);

        // this calculation is based on the assumption that the DS token has 18 decimals but pa can have different decimals

        TransferHelper.transferFromNormalize(pa, minter, paAmount);
        dsHistory[dsIndexMap[address(ds)]].totalDeposited += amount;

        _mint(minter, amount);

        emit Mint(minter, amount);
    }

    function mint(
        address minter,
        uint256 amount,
        bytes memory rawDsPermitSig,
        bytes memory rawPaPermitSig,
        uint256 deadline
    ) external whenNotPaused nonReentrant autoUpdateDS returns (uint256 dsAmount, uint256 paAmount) {
        if (rawDsPermitSig.length == 0 || rawPaPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }

        if (!PermitChecker.supportsPermit(address(pa))) {
            revert PermitNotSupported();
        }

        (dsAmount, paAmount) = previewMint(amount);

        Signature memory sig = MinimalSignatureHelper.split(rawDsPermitSig);
        ds.permit(minter, address(this), dsAmount, deadline, sig.v, sig.r, sig.s, "mint");

        sig = MinimalSignatureHelper.split(rawPaPermitSig);
        IERC20Permit(address(pa)).permit(minter, address(this), paAmount, deadline, sig.v, sig.r, sig.s);

        (uint256 _actualDs, uint256 _actualPa) = __mint(minter, amount);

        assert(_actualDs == dsAmount);
        assert(_actualPa == paAmount);
    }

    /**
     * @notice Returns the dsAmount and paAmount received for dissolving the specified amount of HedgeUnit tokens.
     * @return dsAmount The amount of DS tokens received for dissolving the specified amount of HedgeUnit tokens.
     * @return paAmount The amount of pa tokens received for dissolving the specified amount of HedgeUnit tokens.
     */
    function previewDissolve(uint256 amount)
        public
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount)
    {
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }
        uint256 totalLiquidity = totalSupply();
        uint256 reservePa = _selfPaReserve();
        uint256 reserveDs = ds.balanceOf(address(this));
        uint256 reserveRa = _selfRaReserve();

        (paAmount, dsAmount, raAmount) = HedgeUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, amount);
    }

    /**
     * @notice Dissolves HedgeUnit tokens and returns the equivalent amount of DS and pa tokens.
     * @param amount The amount of HedgeUnit tokens to dissolve.
     * @return dsAmount The amount of DS tokens returned.
     * @return paAmount The amount of pa tokens returned.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts InvalidAmount if the user has insufficient HedgeUnit balance.
     */
    function dissolve(uint256 amount)
        external
        whenNotPaused
        nonReentrant
        autoUpdateDS
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount)
    {
        (dsAmount, paAmount, raAmount) = _dissolve(amount);
    }

    function _dissolve(uint256 amount) internal returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount) {
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }

        (dsAmount, paAmount, raAmount) = previewDissolve(amount);

        TransferHelper.transferNormalize(pa, msg.sender, paAmount);
        _transferDs(msg.sender, dsAmount);
        TransferHelper.transferNormalize(ra, msg.sender, raAmount);

        _burn(msg.sender, amount);

        emit Dissolve(msg.sender, amount, dsAmount, paAmount);
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
        return HedgeUnitMath.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }
}
