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
import {DummyERCWithPermit} from "./../../contracts/dummy/DummyERCWithPermit.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import {TestModuleCore} from "./TestModuleCore.sol";
import {TestFlashSwapRouter} from "./TestFlashSwapRouter.sol";
import {SigUtils} from "./SigUtils.sol";
import {TestHelper} from "Cork-Hook/../test/Helper.sol";
import {IDsFlashSwapCore} from "./../../contracts/interfaces/IDsFlashSwapRouter.sol";
import "./../../contracts/core/Withdrawal.sol";
import "./../../contracts/core/assets/ProtectedUnitFactory.sol";
import {ProtectedUnitRouter} from "../../contracts/core/assets/ProtectedUnitRouter.sol";
import {Permit2} from "./../../script/foundry-scripts/Utils/Permit2Mock.sol";
import {ProtectedUnit} from "./../../contracts/core/assets/ProtectedUnit.sol";

contract CustomErc20 is DummyWETH {
    uint8 internal __decimals;

    constructor(uint8 _decimals) DummyWETH() {
        __decimals = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return __decimals;
    }
}

abstract contract Helper is SigUtils, TestHelper {
    TestModuleCore internal moduleCore;
    AssetFactory internal assetFactory;
    IUniswapV2Factory internal uniswapFactory;
    IUniswapV2Router02 internal uniswapRouter;
    CorkConfig internal corkConfig;
    TestFlashSwapRouter internal flashSwapRouter;
    DummyWETH internal weth = new DummyWETH();
    Withdrawal internal withdrawalContract;
    ProtectedUnitFactory internal protectedUnitFactory;
    ProtectedUnitRouter internal protectedUnitRouter;
    address internal permit2;
    address internal protectedUnitImpl;
    EnvGetters internal env = new EnvGetters();

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

    // 10% initial ds price
    uint256 internal constant DEFAULT_INITIAL_DS_PRICE = 0.1 ether;

    // 50% split percentage
    uint256 internal DEFAULT_CT_SPLIT_PERCENTAGE = 50 ether;

    uint8 internal constant TARGET_DECIMALS = 18;

    uint8 internal constant MAX_DECIMALS = 64;

    address internal constant CORK_PROTOCOL_TREASURY = address(789);

    address private overridenAddress;

    // 10% sell pressure threshold for the router
    uint256 internal DEFAULT_SELLPRESSURE_THRESHOLD = 10 ether;

    function overridePrank(address _as) public {
        (, address currentCaller,) = vm.readCallers();
        overridenAddress = currentCaller;
        vm.startPrank(_as);
    }

    function revertPrank() public {
        vm.stopPrank();
        vm.startPrank(overridenAddress);

        overridenAddress = address(0);
    }

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
        assetFactory.setModuleCore(address(moduleCore));
    }

    function defaultBuyApproxParams() internal pure returns (IDsFlashSwapCore.BuyAprroxParams memory) {
        return IDsFlashSwapCore.BuyAprroxParams(256, 256, 1e16, 1e9, 1e9, 0.01 ether);
    }

    function defaultOffchainGuessParams() internal pure returns (IDsFlashSwapCore.OffchainGuess memory params) {
        // we return 0 since in most cases, we want to actually test the on-chain calculation logic
        params.borrowOnBuy = 0;
        params.borrowOnFill = 0;
    }

    function initializeNewModuleCore(
        address pa,
        address ra,
        uint256 initialDsPrice,
        uint256 baseRedemptionFee,
        uint256 expiryInSeconds
    ) internal {
        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());

        corkConfig.initializeModuleCore(pa, ra, initialDsPrice, expiryInSeconds, exchangeRateProvider);
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, baseRedemptionFee);

        corkConfig.updatePsmRate(defaultCurrencyId, DEFAULT_EXCHANGE_RATES);
    }

    function initializeNewModuleCore(address pa, address ra, uint256 initialDsPrice, uint256 expiryInSeconds)
        internal
    {
        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());

        corkConfig.initializeModuleCore(pa, ra, initialDsPrice, expiryInSeconds, exchangeRateProvider);
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, DEFAULT_BASE_REDEMPTION_FEE);

        corkConfig.updatePsmRate(defaultCurrencyId, DEFAULT_EXCHANGE_RATES);
    }

    function issueNewDs(
        Id id,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) internal {
        corkConfig.issueNewDs(id, block.timestamp + 10 seconds);

        corkConfig.updateDecayDiscountRateInDays(decayDiscountRateInDays);
        corkConfig.updateRolloverPeriodInBlocks(rolloverPeriodInblocks);
        corkConfig.updateRepurchaseFeeRate(id, repurchaseFeePercentage);
        corkConfig.updateReserveSellPressurePercentage(id, DEFAULT_SELLPRESSURE_THRESHOLD);
    }

    function issueNewDs(Id id) internal {
        issueNewDs(
            id,
            defaultExchangeRate(),
            DEFAULT_REPURCHASE_FEE,
            DEFAULT_DECAY_DISCOUNT_RATE,
            block.number + DEFAULT_ROLLOVER_PERIOD
        );
    }

    function initializeAndIssueNewDsWithRaAsPermit(uint256 expiryInSeconds)
        internal
        returns (DummyERCWithPermit ra, DummyERCWithPermit pa, Id id)
    {
        if (block.timestamp + expiryInSeconds > block.timestamp + 100 days) {
            revert(
                "Expiry too far in the future, specify a default decay rate, this will cause the discount to exceed 100!"
            );
        }

        ra = new DummyERCWithPermit("RA", "RA");
        pa = new DummyERCWithPermit("PA", "PA");

        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());
        Pair memory _id =
            PairLibrary.initalize(address(pa), address(ra), defaultInitialArp(), expiryInSeconds, exchangeRateProvider);
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(
            address(pa), address(ra), defaultInitialArp(), DEFAULT_BASE_REDEMPTION_FEE, expiryInSeconds
        );
        issueNewDs(
            id, defaultExchangeRate(), DEFAULT_REPURCHASE_FEE, DEFAULT_DECAY_DISCOUNT_RATE, DEFAULT_ROLLOVER_PERIOD
        );

        corkConfig.updateLvStrategyCtSplitPercentage(defaultCurrencyId, DEFAULT_CT_SPLIT_PERCENTAGE);
    }

    function initializeAndIssueNewDs(uint256 expiryInSeconds) internal returns (DummyWETH ra, DummyWETH pa, Id id) {
        if (block.timestamp + expiryInSeconds > block.timestamp + 100 days) {
            revert(
                "Expiry too far in the future, specify a default decay rate, this will cause the discount to exceed 100!"
            );
        }

        ra = new DummyWETH();
        pa = new DummyWETH();

        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());

        Pair memory _id =
            PairLibrary.initalize(address(pa), address(ra), defaultInitialArp(), expiryInSeconds, exchangeRateProvider);
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(
            address(pa), address(ra), defaultInitialArp(), DEFAULT_BASE_REDEMPTION_FEE, expiryInSeconds
        );
        issueNewDs(
            id, defaultExchangeRate(), DEFAULT_REPURCHASE_FEE, DEFAULT_DECAY_DISCOUNT_RATE, DEFAULT_ROLLOVER_PERIOD
        );

        corkConfig.updateLvStrategyCtSplitPercentage(defaultCurrencyId, DEFAULT_CT_SPLIT_PERCENTAGE);
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

        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());

        Pair memory _id =
            PairLibrary.initalize(address(pa), address(ra), defaultInitialArp(), expiryInSeconds, exchangeRateProvider);
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(address(pa), address(ra), defaultInitialArp(), baseRedemptionFee, expiryInSeconds);
        issueNewDs(
            defaultCurrencyId,
            DEFAULT_EXCHANGE_RATES,
            DEFAULT_REPURCHASE_FEE,
            DEFAULT_DECAY_DISCOUNT_RATE,
            DEFAULT_ROLLOVER_PERIOD
        );
        corkConfig.updateLvStrategyCtSplitPercentage(defaultCurrencyId, DEFAULT_CT_SPLIT_PERCENTAGE);
    }

    function initializeAndIssueNewDs(uint256 expiryInSeconds, uint8 raDecimals, uint8 paDecimals)
        internal
        returns (DummyWETH ra, DummyWETH pa, Id id)
    {
        if (block.timestamp + expiryInSeconds > block.timestamp + 100 days) {
            revert(
                "Expiry too far in the future, specify a default decay rate, this will cause the discount to exceed 100!"
            );
        }

        ra = new CustomErc20(raDecimals);
        pa = new CustomErc20(paDecimals);

        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());

        Pair memory _id =
            PairLibrary.initalize(address(pa), address(ra), defaultInitialArp(), expiryInSeconds, exchangeRateProvider);
        id = PairLibrary.toId(_id);

        defaultCurrencyId = id;

        initializeNewModuleCore(
            address(pa), address(ra), defaultInitialArp(), DEFAULT_BASE_REDEMPTION_FEE, expiryInSeconds
        );
        issueNewDs(
            id, DEFAULT_EXCHANGE_RATES, DEFAULT_REPURCHASE_FEE, DEFAULT_DECAY_DISCOUNT_RATE, DEFAULT_ROLLOVER_PERIOD
        );
        corkConfig.updateLvStrategyCtSplitPercentage(defaultCurrencyId, DEFAULT_CT_SPLIT_PERCENTAGE);
    }

    function initializeAndIssueNewDs(
        uint256 expiryInSeconds,
        uint256 exchangeRates,
        uint256 repurchaseFeePercentage,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks,
        uint256 initialDsPrice
    ) internal returns (DummyWETH ra, DummyWETH pa, Id id) {
        ra = new DummyWETH();
        pa = new DummyWETH();

        address exchangeRateProvider = address(corkConfig.defaultExchangeRateProvider());

        Pair memory _id =
            PairLibrary.initalize(address(pa), address(ra), initialDsPrice, expiryInSeconds, exchangeRateProvider);
        id = PairLibrary.toId(_id);

        initializeNewModuleCore(address(pa), address(ra), initialDsPrice, expiryInSeconds);
        issueNewDs(id, exchangeRates, repurchaseFeePercentage, decayDiscountRateInDays, rolloverPeriodInblocks);
    }

    function deployConfig() internal {
        corkConfig = new CorkConfig(DEFAULT_ADDRESS, DEFAULT_ADDRESS);
        corkConfig.setHook(address(hook));

        // transfer hook onwer to corkConfig
        overridePrank(DEFAULT_HOOK_OWNER);
        hook.transferOwnership(address(corkConfig));
        revertPrank();
    }

    function setupConfig() internal {
        corkConfig.setModuleCore(address(moduleCore));
        corkConfig.setFlashSwapCore(address(flashSwapRouter));
        corkConfig.setTreasury(CORK_PROTOCOL_TREASURY);
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

    function initializeWithdrawalContract() internal {
        withdrawalContract = new Withdrawal(address(moduleCore));

        corkConfig.setWithdrawalContract(address(withdrawalContract));
    }

    function disableDsGradualSale() internal {
        disableDsGradualSale(defaultCurrencyId);
    }

    function disableDsGradualSale(Id id) internal {
        corkConfig.updateRouterGradualSaleStatus(id, true);
    }

    function deployModuleCore() internal {
        __workaround();

        // workaround for uni v4
        overridePrank(address(this));
        setupTest();
        revertPrank();

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
        initializeWithdrawalContract();
        initializePermit2();
        initializeProtectedUnitFactory();
    }

    function initializePermit2() internal {
        permit2 = address(new Permit2());
    }

    function initializeProtectedUnitFactory() internal {
        protectedUnitImpl = address(new ProtectedUnit());
        ERC1967Proxy protectedUnitProxy = new ERC1967Proxy(
            address(new ProtectedUnitFactory()),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address)",
                address(moduleCore),
                address(corkConfig),
                address(flashSwapRouter),
                permit2,
                protectedUnitImpl
            )
        );
        protectedUnitFactory = ProtectedUnitFactory(address(protectedUnitProxy));

        protectedUnitRouter = new ProtectedUnitRouter(permit2);
        corkConfig.setProtectedUnitFactory(address(protectedUnitFactory));
    }

    function forceUnpause(Id id) internal {
        corkConfig.updatePsmDepositsStatus(id, false);
        corkConfig.updatePsmWithdrawalsStatus(id, false);
        corkConfig.updatePsmRepurchasesStatus(id, false);
        corkConfig.updateLvDepositsStatus(id, false);
        corkConfig.updateLvWithdrawalsStatus(id, false);
    }

    function forceUnpause() internal {
        forceUnpause(defaultCurrencyId);
    }

    function __workaround() internal {
        PrankWorkAround _contract = new PrankWorkAround();
        _contract.prankApply();
    }

    function envStringNoRevert(string memory key) internal view returns (string memory) {
        try env.envString(key) returns (string memory value) {
            return value;
        } catch {
            return "";
        }
    }

    function envUintNoRevert(string memory key) internal view returns (uint256) {
        try env.envUint(key) returns (uint256 value) {
            return value;
        } catch {
            return 0;
        }
    }
}

contract EnvGetters is TestHelper {
    function envString(string memory key) public view returns (string memory) {
        return vm.envString(key);
    }

    function envUint(string memory key) public view returns (uint256) {
        return vm.envUint(key);
    }
}

contract PrankWorkAround {
    constructor() {
        // This is a workaround to apply the prank to the contract
        // since uniswap does whacky things with the contract creation
    }

    function prankApply() public {
        // This is a workaround to apply the prank to the contract
        // since uniswap does whacky things with the contract creation
    }
}
