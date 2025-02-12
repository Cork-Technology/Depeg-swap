pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SetupMarketScript is Script {
    CorkConfig public config = CorkConfig(0x4f217EDafBd17eC975D7e05DDafc4634fbdb258F);
    ModuleCore public moduleCore = ModuleCore(0x0dCd8A118566ec6b8B96A3334C4B5A1DB2345d72);
    address public defaultExchangeProvider = 0xeF72B8f15f4DD2A4E124B9D16F5B7c76e0DF5781;

    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 constant weth_wstETH_Expiry = 90 days;
    uint256 constant wstETH_weETH_Expiry = 90 days;
    uint256 constant sUSDS_USDe_Expiry = 90 days;
    uint256 constant sUSDe_USDT_Expiry = 90 days;

    uint256 constant weth_wstETH_ARP = 0.3698630137 ether;
    uint256 constant wstETH_weETH_ARP = 0.4931506849 ether;
    uint256 constant sUSDS_USDe_ARP = 0.9863013699 ether;
    uint256 constant sUSDe_USDT_ARP = 0.4931506849 ether;

    uint256 constant weth_wstETH_ExchangeRate = 1.192057609 ether;
    uint256 constant wstETH_weETH_ExchangeRate = 0.8881993472 ether;
    uint256 constant sUSDS_USDe_ExchangeRate = 0.9689922481 ether;
    uint256 constant sUSDe_USDT_ExchangeRate = 0.8680142355 ether;

    uint256 constant weth_wstETH_RedemptionFee = 0.2 ether;
    uint256 constant wstETH_weETH_RedemptionFee = 0.2 ether;
    uint256 constant sUSDS_USDe_RedemptionFee = 0.2 ether;
    uint256 constant sUSDe_USDT_RedemptionFee = 0.2 ether;

    uint256 constant weth_wstETH_RepurchaseFee = 0.23 ether;
    uint256 constant wstETH_weETH_RepurchaseFee = 0.3 ether;
    uint256 constant sUSDS_USDe_RepurchaseFee = 0.61 ether;
    uint256 constant sUSDe_USDT_RepurchaseFee = 0.3 ether;

    uint256 constant weth_wstETH_AmmBaseFee = 0.018 ether;
    uint256 constant wstETH_weETH_AmmBaseFee = 0.025 ether;
    uint256 constant sUSDS_USDe_AmmBaseFee = 0.049 ether;
    uint256 constant sUSDe_USDT_AmmBaseFee = 0.025 ether;

    uint256 constant weth_wstETH_FeesSplit = 0 ether;
    uint256 constant wstETH_weETH_FeesSplit = 10 ether;
    uint256 constant sUSDS_USDe_FeesSplit = 10 ether;
    uint256 constant sUSDe_USDT_FeesSplit = 10 ether;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                        : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        setupMarket(wstETH, weth, weth_wstETH_Expiry, weth_wstETH_ARP, weth_wstETH_ExchangeRate);
        configureFees(
            wstETH,
            weth,
            weth_wstETH_ARP,
            weth_wstETH_Expiry,
            weth_wstETH_RedemptionFee,
            weth_wstETH_RepurchaseFee,
            weth_wstETH_AmmBaseFee,
            weth_wstETH_FeesSplit
        );

        setupMarket(weETH, wstETH, wstETH_weETH_Expiry, wstETH_weETH_ARP, wstETH_weETH_ExchangeRate);
        configureFees(
            weETH,
            wstETH,
            wstETH_weETH_ARP,
            wstETH_weETH_Expiry,
            wstETH_weETH_RedemptionFee,
            wstETH_weETH_RepurchaseFee,
            wstETH_weETH_AmmBaseFee,
            wstETH_weETH_FeesSplit
        );

        setupMarket(USDe, sUSDS, sUSDS_USDe_Expiry, sUSDS_USDe_ARP, sUSDS_USDe_ExchangeRate);
        configureFees(
            USDe,
            sUSDS,
            sUSDS_USDe_ARP,
            sUSDS_USDe_Expiry,
            sUSDS_USDe_RedemptionFee,
            sUSDS_USDe_RepurchaseFee,
            sUSDS_USDe_AmmBaseFee,
            sUSDS_USDe_FeesSplit
        );

        setupMarket(USDT, sUSDe, sUSDe_USDT_Expiry, sUSDe_USDT_ARP, sUSDe_USDT_ExchangeRate);
        configureFees(
            USDT,
            sUSDe,
            sUSDe_USDT_ARP,
            sUSDe_USDT_Expiry,
            sUSDe_USDT_RedemptionFee,
            sUSDe_USDT_RepurchaseFee,
            sUSDe_USDT_AmmBaseFee,
            sUSDe_USDT_FeesSplit
        );
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function setupMarket(
        address paToken,
        address raToken,
        uint256 expiryPeriod,
        uint256 initialARP,
        uint256 exchangeRate
    ) public {
        console.log("Pair: ", ERC20(raToken).name(), "-", ERC20(paToken).name());

        config.initializeModuleCore(paToken, raToken, initialARP, expiryPeriod, defaultExchangeProvider);
        console.log("New Market created");

        Id id = moduleCore.getId(paToken, raToken, initialARP, expiryPeriod, defaultExchangeProvider);
        config.updatePsmRate(id, exchangeRate);
        console.log("Updated Exchange Rate");

        config.issueNewDs(id, block.timestamp + 30 minutes);
        console.log("New DS issued for pair");
        console.log("");

        console.log("paToken                 : ", paToken);
        console.log("raToken                 : ", raToken);
        console.log("ARP                     : ", percentage(initialARP), "%");
        console.log("Expiry                  : ", expiryPeriod / 1 days, "days");
        console.log("exchangeRate            : ", percentage(exchangeRate));
        console.log("Decay Rate              :  0");
        console.log("Rollover period         : ", block.timestamp + 7200, "timestamp");
        console.log("AMM liquidation deadline: ", block.timestamp + 30 minutes, "timestamp");
    }

    function configureFees(
        address paToken,
        address raToken,
        uint256 initialARP,
        uint256 expiryPeriod,
        uint256 redmptionFee,
        uint256 repurchaseFee,
        uint256 ammBaseFeePercentage,
        uint256 feesSplit
    ) public {
        Id id = moduleCore.getId(paToken, raToken, initialARP, expiryPeriod, defaultExchangeProvider);
        config.updatePsmBaseRedemptionFeePercentage(id, redmptionFee);
        config.updateRepurchaseFeeRate(id, repurchaseFee);
        config.updateAmmBaseFeePercentage(id, ammBaseFeePercentage);
        config.updateRouterDsExtraFee(id, 10 ether); // 10% fees
        config.updateReserveSellPressurePercentage(id, 45 ether); // 45%

        config.updateAmmTreasurySplitPercentage(id, feesSplit);
        config.updatePsmBaseRedemptionFeeTreasurySplitPercentage(id, feesSplit);
        config.updatePsmRepurchaseFeeTreasurySplitPercentage(id, feesSplit);
        config.updateDsExtraFeeTreasurySplitPercentage(id, feesSplit);
        config.updateLvStrategyCtSplitPercentage(id, 0); // 0%

        console.log("Redemption Fee          : ", percentage(redmptionFee), "%");
        console.log("Repurchase Fee          : ", percentage(repurchaseFee), "%");
        console.log("AMM Base Fee            : ", percentage(ammBaseFeePercentage), "%");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
    }

    function percentage(uint256 value) public view returns (string memory) {
        uint256 scale = 1e18; // Ether conversion
        uint256 precision = 1000000; // To retain six decimal places

        uint256 wholePart = value / scale; // Get the integer part
        uint256 fractionalPart = (value % scale) * precision / scale; // Get the fractional part
        return string.concat(Strings.toString(wholePart), ".", Strings.toString(fractionalPart));
    }
}
