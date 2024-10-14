pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHedgeUnit} from "../../interfaces/IHedgeUnit.sol";

contract HedgeUnit is ERC20, ReentrancyGuard, Ownable, IHedgeUnit {
    using SafeERC20 for IERC20;

    IERC20 public immutable DS;
    IERC20 public immutable PA;

    bool public mintingPaused;
    uint256 public mintCap;

    constructor(address _DS, address _PA, string memory _pairName, uint256 _mintCap)
        ERC20(string(abi.encodePacked("Hedge Unit - ", _pairName)), string(abi.encodePacked("HU - ", _pairName)))
        Ownable(msg.sender)
    {
        DS = IERC20(_DS);
        PA = IERC20(_PA);
        mintCap = _mintCap;
    }

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

    function setMintingPaused(bool _paused) external onlyOwner {
        if (_paused == mintingPaused) {
            revert InvalidValue();
        }
        mintingPaused = _paused;
        emit MintingPausedSet(_paused);
    }

    function updateMintCap(uint256 _newMintCap) external onlyOwner {
        if (_newMintCap == mintCap) {
            revert InvalidValue();
        }
        mintCap = _newMintCap;
        emit MintCapUpdated(_newMintCap);
    }
}
