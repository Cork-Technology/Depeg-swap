pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHedgeUnit} from "../../interfaces/IHedgeUnit.sol";

/**
 * @title HedgeUnit
 * @notice This contract allows minting and dissolving HedgeUnit tokens in exchange for two underlying assets.
 * @dev The contract uses OpenZeppelin's ERC20, ReentrancyGuard, and Ownable modules.
 */
contract HedgeUnit is ERC20, ReentrancyGuard, Ownable, IHedgeUnit {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token representing the DS asset.
    IERC20 public immutable DS;

    /// @notice The ERC20 token representing the PA asset.
    IERC20 public immutable PA;

    /// @notice Flag to indicate if minting is currently paused.
    bool public mintingPaused;

    /// @notice Maximum supply cap for minting HedgeUnit tokens.
    uint256 public mintCap;

    /**
     * @dev Constructor that sets the DS and PA tokens and initializes the mint cap.
     * @param _DS Address of the DS token.
     * @param _PA Address of the PA token.
     * @param _pairName Name of the HedgeUnit pair.
     * @param _mintCap Initial mint cap for the HedgeUnit tokens.
     */
    constructor(address _DS, address _PA, string memory _pairName, uint256 _mintCap)
        ERC20(string(abi.encodePacked("Hedge Unit - ", _pairName)), string(abi.encodePacked("HU - ", _pairName)))
        Ownable(msg.sender)
    {
        DS = IERC20(_DS);
        PA = IERC20(_PA);
        mintCap = _mintCap;
    }

    /**
     * @notice Mints HedgeUnit tokens by transferring the equivalent amount of DS and PA tokens.
     * @dev The function checks for the paused state and mint cap before minting.
     * @param amount The amount of HedgeUnit tokens to mint.
     * @custom:reverts MintingPaused if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     */
    function mint(uint256 amount) external nonReentrant {
        if (mintingPaused) {
            revert MintingPaused();
        }
        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        DS.safeTransferFrom(msg.sender, address(this), amount);
        PA.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);

        emit Mint(msg.sender, amount);
    }

    /**
     * @notice Dissolves HedgeUnit tokens and returns the equivalent amount of DS and PA tokens.
     * @param amount The amount of HedgeUnit tokens to dissolve.
     * @return dsAmount The amount of DS tokens returned.
     * @return paAmount The amount of PA tokens returned.
     * @custom:reverts InvalidAmount if the user has insufficient HedgeUnit balance.
     */
    function dissolve(uint256 amount) external nonReentrant returns (uint256 dsAmount, uint256 paAmount) {
        if (amount > balanceOf(msg.sender)) {
            revert InvalidAmount();
        }

        uint256 totalSupplyHU = totalSupply();

        dsAmount = (amount * DS.balanceOf(address(this))) / totalSupplyHU;
        paAmount = (amount * PA.balanceOf(address(this))) / totalSupplyHU;

        _burn(msg.sender, amount);
        DS.safeTransfer(msg.sender, dsAmount);
        PA.safeTransfer(msg.sender, paAmount);

        emit Dissolve(msg.sender, amount, dsAmount, paAmount);
    }

    /**
     * @notice Sets the paused state for minting.
     * @param _paused The new paused state (true to pause, false to unpause).
     * @custom:reverts InvalidValue if the paused state is not changed.
     */
    function setMintingPaused(bool _paused) external onlyOwner {
        if (_paused == mintingPaused) {
            revert InvalidValue();
        }
        mintingPaused = _paused;
        emit MintingPausedSet(_paused);
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
}
