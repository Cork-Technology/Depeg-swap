// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IDepegSwapMarket {
    function getAvailableSwaps() external view returns (uint256);
    function sellPeggedAsset(uint256 amount) external returns (uint256);
    function getCurrentPrice() external view returns (uint256);
    function convertPeggedToRedemption(uint256 amount) external returns (uint256);
    function buyDepegSwaps(uint256 redemptionAssetAmount) external returns (uint256);
}

interface IRedemptionPool {
    function redeem(uint256 peggedAmount, uint256 depegSwapAmount) external returns (uint256);
}

abstract contract HedgedUnit is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public peggedAsset;
    IERC20 public depegSwap;
    IERC20 public redemptionAsset;
    IPriceOracle public priceOracle;
    IDepegSwapMarket public depegSwapMarket;
    IRedemptionPool public redemptionPool;

    bool public mintingPaused;

    uint256 public constant PRECISION = 1e18;
    uint256 public mintCap;
    uint256 public totalSupply;
    uint256 public lastRolloverBlock;
    uint256 public constant BLOCKS_BEFORE_EXPIRY = 100;
    uint256 public constant DEPEG_THRESHOLD = 1e16;
    uint256 public constant BLOCKS_BEFORE_SHORTAGE_CHECK = 200;

    mapping(address => uint256) public balanceOf;

    event Mint(address indexed user, uint256 amount);
    event Dissolve(address indexed user, uint256 amount);
    event RolloverExecuted(uint256 newDepegSwapAmount);
    event DepegScenarioActivated();
    event DepegSwapShortageHandled(uint256 unhedgedAmount);

    constructor(
        address _peggedAsset,
        address _depegSwap,
        address _redemptionAsset,
        uint256 _initialMintCap,
        address _redemptionPool
    ) {
        peggedAsset = IERC20(_peggedAsset);
        depegSwap = IERC20(_depegSwap);
        redemptionAsset = IERC20(_redemptionAsset);
        mintCap = _initialMintCap;
        redemptionPool = IRedemptionPool(_redemptionPool);
    }

    function mint(uint256 amount) external {
        require(!mintingPaused, "Minting is paused");

        require(totalSupply + amount <= mintCap, "Mint cap exceeded");

        balanceOf[msg.sender] += amount;
        totalSupply += amount;

        peggedAsset.safeTransferFrom(msg.sender, address(this), amount);
        depegSwap.safeTransferFrom(msg.sender, address(this), amount);

        emit Mint(msg.sender, amount);
    }

    function dissolve(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient HU");

        uint256 peggedAssetAmount = (peggedAsset.balanceOf(address(this)) * amount) / totalSupply;
        uint256 depegSwapAmount = (depegSwap.balanceOf(address(this)) * amount) / totalSupply;
        uint256 redemptionAssetAmount = (redemptionAsset.balanceOf(address(this)) * amount) / totalSupply;

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        peggedAsset.safeTransfer(msg.sender, peggedAssetAmount);
        depegSwap.safeTransfer(msg.sender, depegSwapAmount);
        redemptionAsset.safeTransfer(msg.sender, redemptionAssetAmount);

        emit Dissolve(msg.sender, amount);
    }

    function executeRollover(uint256 newDepegSwapAmount) external onlyOwner {
        depegSwap.safeTransferFrom(msg.sender, address(this), newDepegSwapAmount);

        emit RolloverExecuted(newDepegSwapAmount);
    }

    function handleDepegSwapShortage(uint256 amountToSell) external onlyOwner {
        peggedAsset.safeTransfer(address(this), amountToSell);
        mintingPaused = true;
    }

    function setMintCap(uint256 newMintCap) external onlyOwner {
        mintCap = newMintCap;
    }

    function toggleMinting() external onlyOwner {
        mintingPaused = !mintingPaused;
    }

    function executeRollover() external onlyOwner {
        require(block.number >= lastRolloverBlock + BLOCKS_BEFORE_EXPIRY, "Too early for rollover");

        if (isDepegScenario()) {
            handleDepegScenario();
        } else if (isDepegSwapShortage()) {
            handleDepegSwapShortage();
        } else {
            executeBaseScenarioRollover();
        }

        lastRolloverBlock = block.number;
    }

    function isDepegScenario() internal view returns (bool) {
        uint256 peggedAssetPrice = getPeggedAssetPrice();
        return peggedAssetPrice <= (PRECISION - DEPEG_THRESHOLD);
    }

    function isDepegSwapShortage() internal view returns (bool) {
        uint256 availableDepegSwaps = getAvailableDepegSwaps();
        uint256 requiredDepegSwaps = peggedAsset.balanceOf(address(this));
        return availableDepegSwaps < requiredDepegSwaps;
    }

    function handleDepegScenario() internal {
        uint256 peggedAssetBalance = peggedAsset.balanceOf(address(this));
        uint256 depegSwapBalance = depegSwap.balanceOf(address(this));

        redeemAssets(peggedAssetBalance, depegSwapBalance);

        mintingPaused = true;
        emit DepegScenarioActivated();
    }

    function handleDepegSwapShortage() internal {
        uint256 availableDepegSwaps = getAvailableDepegSwaps();
        uint256 peggedAssetBalance = peggedAsset.balanceOf(address(this));
        uint256 unhedgedAmount = peggedAssetBalance - availableDepegSwaps;

        sellPeggedAsset(unhedgedAmount);

        mintingPaused = true;
        emit DepegSwapShortageHandled(unhedgedAmount);
    }

    function executeBaseScenarioRollover() internal {
        uint256 peggedAssetBalance = peggedAsset.balanceOf(address(this));
        uint256 requiredRedemptionAsset = calculateRequiredRedemptionAsset(peggedAssetBalance);

        convertPeggedToRedemption(requiredRedemptionAsset);

        uint256 newDepegSwapAmount = buyDepegSwaps(requiredRedemptionAsset);

        emit RolloverExecuted(newDepegSwapAmount);
    }

    function getPeggedAssetPrice() internal view returns (uint256) {}

    function getAvailableDepegSwaps() internal view returns (uint256) {}

    function redeemAssets(uint256 peggedAmount, uint256 depegSwapAmount) internal {
        peggedAsset.approve(address(redemptionPool), peggedAmount);
        depegSwap.approve(address(redemptionPool), depegSwapAmount);

        uint256 redeemedAmount = redemptionPool.redeem(peggedAmount, depegSwapAmount);

        redemptionAsset.safeTransferFrom(address(redemptionPool), address(this), redeemedAmount);
    }

    function sellPeggedAsset(uint256 amount) internal {
        peggedAsset.approve(address(depegSwapMarket), amount);

        uint256 receivedRedemptionAsset = depegSwapMarket.sellPeggedAsset(amount);

        redemptionAsset.safeTransferFrom(address(depegSwapMarket), address(this), receivedRedemptionAsset);
    }

    function calculateRequiredRedemptionAsset(uint256 peggedAssetAmount) internal view returns (uint256) {
        uint256 depegSwapPrice = depegSwapMarket.getCurrentPrice();

        return (peggedAssetAmount * (depegSwapPrice)) / (PRECISION);
    }

    function convertPeggedToRedemption(uint256 amount) internal {
        peggedAsset.approve(address(depegSwapMarket), amount);

        uint256 receivedRedemptionAsset = depegSwapMarket.convertPeggedToRedemption(amount);

        redemptionAsset.safeTransferFrom(address(depegSwapMarket), address(this), receivedRedemptionAsset);
    }

    function buyDepegSwaps(uint256 redemptionAssetAmount) internal returns (uint256) {
        redemptionAsset.approve(address(depegSwapMarket), redemptionAssetAmount);

        uint256 boughtDepegSwaps = depegSwapMarket.buyDepegSwaps(redemptionAssetAmount);

        depegSwap.safeTransferFrom(address(depegSwapMarket), address(this), boughtDepegSwaps);

        return boughtDepegSwaps;
    }
}
