pragma solidity ^0.8.24;

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
import "./SigUtils.sol";

abstract contract Helper is Test, SigUtils {
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

    // use this to test functions as user
    uint256 internal DEFAULT_ADDRESS_PK = 1;
    address internal DEFAULT_ADDRESS = vm.rememberKey(DEFAULT_ADDRESS_PK);

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

    function defaultInitialDsPrice() internal pure virtual returns (uint256) {
        return DEFAULT_INITIAL_DS_PRICE;
    }

    function defaultExchangeRate() internal pure virtual returns (uint256) {
        return DEFAULT_EXCHANGE_RATES;
    }

    function deployAssetFactory() internal {
        assetFactory = new AssetFactory();
    }

    function initializeAssetFactory() internal {
        assetFactory.initialize();
        assetFactory.transferOwnership(address(moduleCore));
    }

    function deployUniswapRouter(address uniswapfactory, address _flashSwapRouter) internal {
        bytes memory constructorArgs = abi.encode(uniswapfactory, weth, _flashSwapRouter);

        address addr = deployCode("test/helper/ext-abi/foundry/uni-v2-router.json", constructorArgs);

        require(addr != address(0), "Router deployment failed");

        uniswapRouter = IUniswapV2Router02(addr);
    }

    function deployUniswapFactory(address feeToSetter, address _flashSwapRouter) internal {
        bytes memory constructorArgs = abi.encode(feeToSetter, _flashSwapRouter);

        address addr = deployCode("test/helper/ext-abi/foundry/uni-v2-factory.json", constructorArgs);

        uniswapFactory = IUniswapV2Factory(addr);
    }

    function initializeNewModuleCore(
        address pa,
        address ra,
        uint256 lvFee,
        uint256 initialDsPrice,
        uint256 baseRedemptionFee
    ) internal {
        corkConfig.initializeModuleCore(pa, ra, lvFee, initialDsPrice, baseRedemptionFee);
    }

    function initializeNewModuleCore(address pa, address ra, uint256 lvFee, uint256 initialDsPrice) internal {
        corkConfig.initializeModuleCore(pa, ra, lvFee, initialDsPrice, DEFAULT_BASE_REDEMPTION_FEE);
    }

    function issueNewDs(
        Id id,
        uint256 expiryInSeconds,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) internal {
        corkConfig.issueNewDs(
            id,
            expiryInSeconds,
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
            expiryInSeconds,
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

        Pair memory _id = PairLibrary.initalize(address(pa), address(ra));
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(
            address(pa), address(ra), DEFAULT_LV_FEE, defaultInitialDsPrice(), DEFAULT_BASE_REDEMPTION_FEE
        );
        issueNewDs(
            id,
            expiryInSeconds,
            defaultExchangeRate(),
            DEFAULT_REPURCHASE_FEE,
            DEFAULT_DECAY_DISCOUNT_RATE,
            DEFAULT_ROLLOVER_PERIOD
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

        Pair memory _id = PairLibrary.initalize(address(pa), address(ra));
        id = PairLibrary.toId(_id);

                defaultCurrencyId = id;


        initializeNewModuleCore(address(pa), address(ra), DEFAULT_LV_FEE, defaultInitialDsPrice(), baseRedemptionFee);
        issueNewDs(
            id,
            expiryInSeconds,
            DEFAULT_EXCHANGE_RATES,
            DEFAULT_REPURCHASE_FEE,
            DEFAULT_DECAY_DISCOUNT_RATE,
            DEFAULT_ROLLOVER_PERIOD
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

        Pair memory _id = PairLibrary.initalize(address(pa), address(ra));
        id = PairLibrary.toId(_id);

        initializeNewModuleCore(address(pa), address(ra), lvFee, initialDsPrice);
        issueNewDs(
            id, expiryInSeconds, exchangeRates, repurchaseFeePercentage, decayDiscountRateInDays, rolloverPeriodInblocks
        );
    }

    function deployConfig() internal {
        corkConfig = new CorkConfig();
    }

    function initializeConfig() internal {
        corkConfig.setModuleCore(address(moduleCore));
    }

    function deployFlashSwapRouter() internal {
        flashSwapRouter = new TestFlashSwapRouter();
    }

    function initializeFlashSwapRouter() internal {
        flashSwapRouter.initialize(address(corkConfig));
        flashSwapRouter.setModuleCore(address(moduleCore));
    }

    function initializeModuleCore() internal {
        moduleCore.initialize(
            address(assetFactory),
            address(uniswapFactory),
            address(flashSwapRouter),
            address(uniswapRouter),
            address(corkConfig)
        );
    }

   function deployModuleCore() internal {
        deployConfig();
        deployFlashSwapRouter();
        deployAssetFactory();
        deployUniswapFactory(address(0), address(flashSwapRouter));
        deployUniswapRouter(address(uniswapFactory), address(flashSwapRouter));

        moduleCore = new TestModuleCore();
        initializeAssetFactory();
        initializeConfig();
        initializeFlashSwapRouter();
        initializeModuleCore();
    }
}
