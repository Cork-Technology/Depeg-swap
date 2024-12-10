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
contract HedgeUnit is ERC20, ReentrancyGuard, Ownable, Pausable, IHedgeUnit {
    using SafeERC20 for IERC20;

    uint8 internal constant TARGET_DECIMALS = 18;

    ICommon public immutable moduleCore;
    ILiquidator public immutable liquidator;
    Id public immutable id;

    /// @notice The ERC20 token representing the pa asset.
    ERC20 public immutable pa;
    uint8 public immutable paDecimals;

    /// @notice The ERC20 token representing the ds asset.
    Asset public ds;

    /// @notice Maximum supply cap for minting HedgeUnit tokens.
    uint256 public mintCap;

    DSData[] public dsHistory;
    mapping(address => uint256) private dsIndexMap;

    error NoValidDSExist();

    /**
     * @dev Constructor that sets the DS and pa tokens and initializes the mint cap.
     * @param _moduleCore Address of the moduleCore.
     * @param _pa Address of the pa token.
     * @param _pairName Name of the HedgeUnit pair.
     * @param _mintCap Initial mint cap for the HedgeUnit tokens.
     */
    constructor(
        address _moduleCore,
        address _liquidator,
        Id _id,
        address _pa,
        address _ra,
        string memory _pairName,
        uint256 _mintCap,
        address _owner
    )
        ERC20(string(abi.encodePacked("Hedge Unit - ", _pairName)), string(abi.encodePacked("HU - ", _pairName)))
        Ownable(_owner)
    {
        moduleCore = ICommon(_moduleCore);
        liquidator = ILiquidator(_liquidator);
        id = _id;
        pa = ERC20(_pa);
        paDecimals = uint8(ERC20(_pa).decimals());
        mintCap = _mintCap;
    }

    function fetchLatestDS() internal view returns (Asset) {
        uint256 dsId = moduleCore.lastDsId(id);
        (, address dsAdd) = moduleCore.swapAsset(id, dsId);

        if (dsAdd == address(0) || Asset(dsAdd).isExpired()) {
            revert NoValidDSExist();
        }

        return Asset(dsAdd);
    }
    /**
     * @dev Internal function to get the latest DS address.
     * Calls moduleCore to get the latest DS id and retrieves the associated DS address.
     */

    function _getLastDS() internal {
        if (address(ds) == address(0) || ds.isExpired()) {
            Asset _ds = fetchLatestDS();

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

        Asset _ds = fetchLatestDS();

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
    function mint(uint256 amount) external whenNotPaused nonReentrant returns (uint256 dsAmount, uint256 paAmount) {
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }
        _getLastDS();

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
    function previewDissolve(uint256 amount) external view returns (uint256 dsAmount, uint256 paAmount) {
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }
        uint256 totalSupplyHU = totalSupply();
        dsAmount = (amount * ds.balanceOf(address(this))) / totalSupplyHU;
        paAmount = (amount * pa.balanceOf(address(this))) / (totalSupplyHU * (10 ** (18 - paDecimals)));
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
        returns (uint256 dsAmount, uint256 paAmount)
    {
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }

        uint256 totalSupplyHU = totalSupply();

        dsAmount = (amount * ds.balanceOf(address(this))) / totalSupplyHU;
        paAmount = (amount * pa.balanceOf(address(this))) / (totalSupplyHU * (10 ** (18 - paDecimals)));

        _burn(msg.sender, amount);
        IERC20(ds).safeTransfer(msg.sender, dsAmount);
        IERC20(pa).safeTransfer(msg.sender, paAmount);

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
