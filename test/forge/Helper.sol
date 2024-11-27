pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ModuleCore} from "./../../contracts/core/ModuleCore.sol";
import {AssetFactory} from "./../../contracts/core/assets/AssetFactory.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IUniswapV2Factory} from "./../../contracts/interfaces/uniswap-v2/factory.sol";
import {IUniswapV2Router02} from "./../../contracts/interfaces/uniswap-v2/RouterV2.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import {CorkConfig} from "./../../contracts/core/CorkConfig.sol";
import {RouterState} from "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import {TestModuleCore} from "./TestModuleCore.sol";
import {TestFlashSwapRouter} from "./TestFlashSwapRouter.sol";
import {SigUtils} from "./SigUtils.sol";
import {TestHelper} from "Cork-Hook/../test/Helper.sol";
import {IDsFlashSwapCore} from "./../../contracts/interfaces/IDsFlashSwapRouter.sol";

abstract contract Helper is SigUtils, TestHelper {
    TestModuleCore internal moduleCore;
    AssetFactory internal assetFactory;
    IUniswapV2Factory internal uniswapFactory;
    IUniswapV2Router02 internal uniswapRouter;
    CorkConfig internal corkConfig;
    TestFlashSwapRouter internal flashSwapRouter;
    DummyWETH internal weth = new DummyWETH();

    Id defaultCurrencyId;

    // 1% base redemption fee
    uint256 internal constant DEFAULT_BASE_REDEMPTION_FEE = 1 ether;

    uint256 internal constant DEFAULT_EXCHANGE_RATES = 1 ether;

    // 1% repurchase fee
    uint256 internal constant DEFAULT_REPURCHASE_FEE = 1 ether;

    // 1% decay discount rate
    uint256 internal constant DEFAULT_DECAY_DISCOUNT_RATE = 1 ether;

    // 10 block rollover period
    uint256 internal constant DEFAULT_ROLLOVER_PERIOD = 100000;

    // 0% liquidity vault early fee
    uint256 internal constant DEFAULT_LV_FEE = 0 ether;

    // 1% initial ds price
    uint256 internal constant DEFAULT_INITIAL_DS_PRICE = 0.1 ether;

    // 50% split percentage
    uint256 internal DEFAULT_CT_SPLIT_PERCENTAGE = 50 ether;

    function defaultInitialArp() internal pure virtual returns (uint256) {
        return DEFAULT_INITIAL_DS_PRICE;
    }

    function defaultExchangeRate() internal pure virtual returns (uint256) {
        return DEFAULT_EXCHANGE_RATES;
    }

    function deployAssetFactory() internal {
        ERC1967Proxy assetFactoryProxy =
            new ERC1967Proxy(address(new AssetFactory()), abi.encodeWithSignature("initialize()"));
        assetFactory = AssetFactory(address(assetFactoryProxy));
    }

    function setupAssetFactory() internal {
        assetFactory.transferOwnership(address(moduleCore));
    }

    function defaultBuyApproxParams() internal pure returns (IDsFlashSwapCore.BuyAprroxParams memory) {
        return IDsFlashSwapCore.BuyAprroxParams(256, 256, 1e16, 1e9, 1e9, 0.01 ether);
    }

    function initializeNewModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 baseRedemptionFee,
        uint256 expiryInSeconds
    ) internal {
        corkConfig.initializeModuleCore(pa, ra, lvFee, initialDsPrice, baseRedemptionFee, expiryInSeconds);
    }

    function initializeNewModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 expiryInSeconds
    ) internal {
        corkConfig.initializeModuleCore(pa, ra, lvFee, initialDsPrice, DEFAULT_BASE_REDEMPTION_FEE, expiryInSeconds);
    }

    function issueNewDs(
        Id id,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) internal {
        corkConfig.issueNewDs(
            id,
            exchangeRates,
            repurchaseFeePercentage,
            decayDiscountRateInDays,
            rolloverPeriodInblocks,
            block.timestamp + 10 seconds
        );
    }

    function issueNewDs(Id id, uint256 expiryInSeconds) internal {
        issueNewDs(
            id,
            defaultExchangeRate(),
            DEFAULT_REPURCHASE_FEE,
            DEFAULT_DECAY_DISCOUNT_RATE,
            block.number + DEFAULT_ROLLOVER_PERIOD
        );
    }

    function initializeAndIssueNewDs(uint256 expiryInSeconds) internal returns (DummyWETH ra, DummyWETH pa, Id id) {
        if (block.timestamp + expiryInSeconds > block.timestamp + 100 days) {
            revert(
                "Expiry too far in the future, specify a default decay rate, this will cause the discount to exceed 100!"
            );
        }

        ra = new DummyWETH();
        pa = new DummyWETH();

        Pair memory _id = PairLibrary.initalize(address(pa), address(ra), expiryInSeconds);
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(
            address(pa), address(ra), DEFAULT_LV_FEE, defaultInitialArp(), DEFAULT_BASE_REDEMPTION_FEE, expiryInSeconds
        );
        issueNewDs(
            id, defaultExchangeRate(), DEFAULT_REPURCHASE_FEE, DEFAULT_DECAY_DISCOUNT_RATE, DEFAULT_ROLLOVER_PERIOD
        );
    }

    function initializeAndIssueNewDs(uint256 expiryInSeconds, uint256 baseRedemptionFee)
        internal
        returns (DummyWETH ra, DummyWETH pa, Id id)
    {
        if (block.timestamp + expiryInSeconds > block.timestamp + 100 days) {
            revert(
                "Expiry too far in the future, specify a default decay rate, this will cause the discount to exceed 100!"
            );
        }

        ra = new DummyWETH();
        pa = new DummyWETH();

        Pair memory _id = PairLibrary.initalize(address(pa), address(ra), expiryInSeconds);
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(
            address(pa), address(ra), DEFAULT_LV_FEE, defaultInitialArp(), baseRedemptionFee, expiryInSeconds
        );
        issueNewDs(
            id, DEFAULT_EXCHANGE_RATES, DEFAULT_REPURCHASE_FEE, DEFAULT_DECAY_DISCOUNT_RATE, DEFAULT_ROLLOVER_PERIOD
        );
    }

    function initializeAndIssueNewDs(
        uint256 expiryInSeconds,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks,
        uint256 lvFee,
        uint256 initialDsPrice
    ) internal returns (DummyWETH ra, DummyWETH pa, Id id) {
        ra = new DummyWETH();
        pa = new DummyWETH();

        Pair memory _id = PairLibrary.initalize(address(pa), address(ra), expiryInSeconds);
        id = PairLibrary.toId(_id);

        initializeNewModuleCore(address(pa), address(ra), lvFee, initialDsPrice, expiryInSeconds);
        issueNewDs(id, exchangeRates, repurchaseFeePercentage, decayDiscountRateInDays, rolloverPeriodInblocks);
    }

    function deployConfig() internal {
        corkConfig = new CorkConfig();
    }

    function setupConfig() internal {
        corkConfig.setModuleCore(address(moduleCore));
        corkConfig.setFlashSwapCore(address(flashSwapRouter));
    }

    function deployFlashSwapRouter() internal {
        ERC1967Proxy flashswapProxy = new ERC1967Proxy(
            address(new TestFlashSwapRouter()), abi.encodeWithSignature("initialize(address)", address(corkConfig))
        );
        flashSwapRouter = TestFlashSwapRouter(address(flashswapProxy));
    }

    function setupFlashSwapRouter() internal {
        flashSwapRouter.setModuleCore(address(moduleCore));
        flashSwapRouter.setHook(address(hook));
    }

    function initializeModuleCore() internal {
        moduleCore.initialize(address(assetFactory), address(hook), address(flashSwapRouter), address(corkConfig));
    }

    function deployModuleCore() internal {
        setupTest();

        deployConfig();
        deployFlashSwapRouter();
        deployAssetFactory();

        ERC1967Proxy moduleCoreProxy = new ERC1967Proxy(
            address(new TestModuleCore()),
            abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                address(assetFactory),
                address(hook),
                address(flashSwapRouter),
                address(corkConfig)
            )
        );
        moduleCore = TestModuleCore(address(moduleCoreProxy));
        setupAssetFactory();
        setupConfig();
        setupFlashSwapRouter();

        corkConfig.updateLvStrategyCtSplitPercentage(defaultCurrencyId, DEFAULT_CT_SPLIT_PERCENTAGE);
    }
}
