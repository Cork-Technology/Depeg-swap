pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
import "forge-std/console.sol";

struct DSData {
    address dsAddress;
    uint256 totalDeposited;
}

/**
 * @title HedgeUnit
 * @notice This contract allows minting and dissolving HedgeUnit tokens in exchange for two underlying assets.
 * @dev The contract uses OpenZeppelin's ERC20, ReentrancyGuard,Pausable and Ownable modules.
 */
contract HedgeUnit is ERC20, ReentrancyGuard, Ownable, Pausable, IHedgeUnit, IHedgeUnitLiquidation {
    using SafeERC20 for IERC20;

    uint8 internal constant TARGET_DECIMALS = 18;

    ICommon public moduleCore;
    CorkConfig public config;
    IDsFlashSwapCore public flashSwapRouter;
    Id public id;

    /// @notice The ERC20 token representing the pa asset.
    ERC20 public pa;
    ERC20 public ra;

    /// @notice The ERC20 token representing the ds asset.
    Asset public ds;

    /// @notice The price tolerance when buying DS. denominated in APY% and 18 decimals. e.g. 1% = 1e18
    uint256 public dsPriceTolerance;

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
        address _flashSwapRouter,
        uint256 _dsPriceTolerance
    )
        ERC20(string(abi.encodePacked("Hedge Unit - ", _pairName)), string(abi.encodePacked("HU - ", _pairName)))
        Ownable(_config)
    {
        moduleCore = ICommon(_moduleCore);
        id = _id;
        pa = ERC20(_pa);
        ra = ERC20(_ra);
        mintCap = _mintCap;
        flashSwapRouter = IDsFlashSwapCore(_flashSwapRouter);
        config = CorkConfig(_config);
        dsPriceTolerance = _dsPriceTolerance;
    }

    modifier autoUpdateDS() {
        _getLastDS();
        _;
    }

    modifier onlyLiquidationContract() {
        if (!config.isLiquidationWhitelisted(msg.sender)) {
            // TODO : replace with custom error
            revert("Only liquidation contract can call this function");
        }
        _;
    }

    modifier onlyValidToken(address token) {
        if (token != address(pa) && token != address(ra)) {
            // TODO : replace with custom error
            revert("Invalid token");
        }
        _;
    }

    function _calculateSpotTolerance() internal view returns (uint256) {
        Asset ds = _fetchLatestDS();

        uint256 start = ds.issuedAt();
        uint256 end = ds.expiry();

        HedgeUnitMath.calculateSpotDsPrice(dsPriceTolerance, start, block.timestamp, end);
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
            // TODO : replace with custom error
            revert("Not enough funds");
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
        returns (uint256 amountOut)
    {
        uint256 dsId = moduleCore.lastDsId(id);

        uint256 dsPriceTolerance = _calculateSpotTolerance();

        amountOut = flashSwapRouter.swapRaforDs(id, dsId, amount, amountOutMin, params);

        if (HedgeUnitMath.isAboveTolerance(dsPriceTolerance, amountOut, amount)) {
            // TODO : replace with custom error
            revert("DS price tolerance exceeded");
        }

        emit FundsUsed(msg.sender, dsId, amount, amountOut);
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
        return _tokenNativeDecimalsToFixed(pa.balanceOf(address(this)), pa);
    }

    function _selfRaReserve() internal view returns (uint256) {
        return _tokenNativeDecimalsToFixed(ra.balanceOf(address(this)), ra);
    }

    function _transferNormalize(ERC20 token, address _to, uint256 _amount) internal {
        uint256 amount = _fixedToTokenNativeDecimals(_amount, token);
        IERC20(pa).safeTransfer(_to, amount);
    }

    function _transferFromNormalize(ERC20 token, address _from, uint256 _amount) internal {
        uint256 amount = _fixedToTokenNativeDecimals(_amount, token);
        IERC20(pa).safeTransferFrom(_from, address(this), amount);
    }

    function _transferDs(address _to, uint256 _amount) internal {
        IERC20(ds).safeTransfer(_to, _amount);
    }

    // TODO : handle Ds renewal
    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of HedgeUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of HedgeUnit tokens.
     * @return paAmount The amount of pa tokens required to mint the specified amount of HedgeUnit tokens.
     */
    function previewMint(uint256 amount) external view returns (uint256 dsAmount, uint256 paAmount) {
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        Asset _ds = _fetchLatestDS();

        uint256 paReserve = _selfPaReserve();

        (dsAmount, paAmount) = HedgeUnitMath.previewMint(amount, paReserve, _ds.balanceOf(address(this)), totalSupply());

        paAmount = _fixedToTokenNativeDecimals(amount, pa);
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
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        {
            uint256 paReserve = _selfPaReserve();

            (dsAmount, paAmount) =
                HedgeUnitMath.previewMint(amount, ds.balanceOf(address(this)), paReserve, totalSupply());

            paAmount = _fixedToTokenNativeDecimals(amount, pa);
        }

        // normalize to token decimals

        IERC20(ds).safeTransferFrom(msg.sender, address(this), dsAmount);

        // this calculation is based on the assumption that the DS token has 18 decimals but pa can have different decimals
        IERC20(pa).safeTransferFrom(msg.sender, address(this), paAmount);
        dsHistory[dsIndexMap[address(ds)]].totalDeposited += amount;

        _mint(msg.sender, amount);

        emit Mint(msg.sender, amount);
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
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }

        (dsAmount, paAmount, raAmount) = previewDissolve(amount);

        _transferNormalize(pa, msg.sender, paAmount);
        _transferDs(msg.sender, dsAmount);
        _transferNormalize(ra, msg.sender, raAmount);

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

    function updateDsPriceTolerance(uint256 _dsPriceTolerance) external onlyOwner {
        dsPriceTolerance = _dsPriceTolerance;
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

    function _tokenNativeDecimalsToFixed(uint256 amount, IERC20Metadata token) public view returns (uint256) {
        uint8 decimals = token.decimals();
        return _normalize(amount, decimals, TARGET_DECIMALS);
    }

    function _fixedToTokenNativeDecimals(uint256 amount, IERC20Metadata token) public view returns (uint256) {
        uint8 decimals = token.decimals();
        return _normalize(amount, TARGET_DECIMALS, decimals);
    }

    function _normalize(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter) public pure returns (uint256) {
        return HedgeUnitMath.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }
}
