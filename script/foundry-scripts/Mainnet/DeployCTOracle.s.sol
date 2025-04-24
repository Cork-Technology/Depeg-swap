pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CorkAdapterFactory} from "../../../contracts/adapters/CorkAdapterFactory.sol";
import {CorkOracleFactory} from "../../../contracts/oracles/CorkOracleFactory.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {CorkHook} from "Cork-Hook/CorkHook.sol";
import {ERC7575PsmAdapter} from "../../../contracts/adapters/ERC7575PsmAdapter.sol";
import {LinearDiscountOracle} from "../../../contracts/oracles/LinearDiscountOracle.sol";
import {PriceFeedParams} from "../../../contracts/interfaces/ICompositePriceFeed.sol";
import {CompositePriceFeed} from "../../../contracts/oracles/CompositePriceFeed.sol";
import {AggregatorV3Interface} from "../../../contracts/interfaces/AggregatorV3Interface.sol";
import {IERC4626} from "../../../contracts/interfaces/IERC4626.sol";

struct Market {
    address redemptionAsset;
    address peggedAsset;
    uint256 expiryInterval;
    uint256 arp;
    uint256 exchangeRate;
    uint256 redemptionFee;
    uint256 repurchaseFee;
    uint256 ammBaseFee;
}

contract DeployCTOracle is Script {
    CorkOracleFactory public corkOracleFactory;
    CorkAdapterFactory public corkAdapterFactory;

    ModuleCore public moduleCore = ModuleCore(0xCCd90F6435dd78C4ECCED1FA4db0D7242548a2a9);
    CorkHook public corkHook = CorkHook(0x5287E8915445aee78e10190559D8Dd21E0E9Ea88);

    address constant exchangeProvider = 0x7b285955DdcbAa597155968f9c4e901bb4c99263;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    uint256 constant wstETH_weETH_Expiry = 90 days + 1;
    uint256 constant wstETH_weETH_ARP = 0.4931506847 ether;
    uint256 constant wstETH_weETH_ExchangeRate = 0.8881993472 ether;
    uint256 constant wstETH_weETH_RedemptionFee = 0.2 ether;
    uint256 constant wstETH_weETH_RepurchaseFee = 0.3 ether;
    uint256 constant wstETH_weETH_AmmBaseFee = 0.025 ether;
    uint256 constant wstETH_weETH_FeesSplit = 10 ether;

    address constant weETH_eth_feed = 0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22;
    address constant stETH_eth_feed = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
    address constant wstETH_stETH_feed = 0x905b7dAbCD3Ce6B792D874e303D336424Cdb1421;

    Market wstETH_weETH_market = Market(
        wstETH,
        weETH,
        wstETH_weETH_Expiry,
        wstETH_weETH_ARP,
        wstETH_weETH_ExchangeRate,
        wstETH_weETH_RedemptionFee,
        wstETH_weETH_RepurchaseFee,
        wstETH_weETH_AmmBaseFee
    );

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                                : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Deploy the Cork Adapter Factory implementation (logic) contract
        CorkAdapterFactory corkAdapterFactoryImplementation = new CorkAdapterFactory();
        console.log("Cork Adapter Factory Implementation     : ", address(corkAdapterFactoryImplementation));

        // Deploy the Cork Adapter Factory Proxy contract
        bytes memory data =
            abi.encodeWithSelector(corkAdapterFactoryImplementation.initialize.selector, deployer, moduleCore, corkHook);
        ERC1967Proxy corkAdapterFactoryProxy = new ERC1967Proxy(address(corkAdapterFactoryImplementation), data);
        corkAdapterFactory = CorkAdapterFactory(address(corkAdapterFactoryProxy));
        console.log("Cork Adapter Factory                    : ", address(corkAdapterFactory));

        // Deploy the Cork Oracle Factory implementation (logic) contract
        CorkOracleFactory corkOracleFactoryImplementation = new CorkOracleFactory();
        console.log("Cork Oracle Factory Implementation      : ", address(corkOracleFactoryImplementation));

        // Deploy the Cork Oracle Factory Proxy contract
        data = abi.encodeWithSelector(corkOracleFactoryImplementation.initialize.selector, deployer, moduleCore);
        ERC1967Proxy corkOracleFactoryProxy = new ERC1967Proxy(address(corkOracleFactoryImplementation), data);
        corkOracleFactory = CorkOracleFactory(address(corkOracleFactoryProxy));
        console.log("Cork Oracle Factory                     : ", address(corkOracleFactory));
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        Market[1] memory markets = [wstETH_weETH_market];

        for (uint256 i = 0; i < markets.length; i++) {
            Market memory market = markets[i];
            Id marketId = moduleCore.getId(
                market.peggedAsset, market.redemptionAsset, market.arp, market.expiryInterval, exchangeProvider
            );
            uint256 dsId = moduleCore.lastDsId(marketId);
            (address ct, address ds) = moduleCore.swapAsset(marketId, dsId);

            // Deploy the Cork Adapter
            address[] memory assets = new address[](2);
            assets[0] = market.redemptionAsset;
            assets[1] = market.peggedAsset;
            ERC7575PsmAdapter[] memory adapters = corkAdapterFactory.createERC7575PsmAdapters(ct, assets, marketId);

            LinearDiscountOracle linearDiscountOracle = corkOracleFactory.createLinearDiscountOracle(ct, 0.02 ether);

            PriceFeedParams[] memory priceFeedParams = new PriceFeedParams[](2);
            priceFeedParams[0] = PriceFeedParams(
                adapters[0],
                1e18,
                AggregatorV3Interface(address(linearDiscountOracle)),
                AggregatorV3Interface(address(0)),
                18,
                IERC4626(address(0)),
                1,
                AggregatorV3Interface(address(0)),
                AggregatorV3Interface(address(0)),
                18
            );
            priceFeedParams[1] = PriceFeedParams(
                adapters[1],
                1e18,
                AggregatorV3Interface(address(linearDiscountOracle)),
                AggregatorV3Interface(weETH_eth_feed),
                18,
                IERC4626(address(0)),
                1,
                AggregatorV3Interface(stETH_eth_feed),
                AggregatorV3Interface(wstETH_stETH_feed),
                18
            );
            CompositePriceFeed compositePriceFeed =
                corkOracleFactory.createCompositePriceFeed(priceFeedParams, keccak256(abi.encodePacked(marketId)));
            console.log("Composite Price Feed                    : ", address(compositePriceFeed));

            (, int256 price,,,) = compositePriceFeed.latestRoundData();
            console.log("Price                                   : ", price);
        }
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
