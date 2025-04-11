pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {TransferHelper} from "./../../../contracts/libraries/TransferHelper.sol";
import {CorkHook} from "Cork-Hook/CorkHook.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SetupMarketScript is Script {
    CorkConfig public config = CorkConfig(0xF0DA8927Df8D759d5BA6d3d714B1452135D99cFC);
    ModuleCore public moduleCore = ModuleCore(0xCCd90F6435dd78C4ECCED1FA4db0D7242548a2a9);
    CorkHook public hook = CorkHook(0x5287E8915445aee78e10190559D8Dd21E0E9Ea88);

    address public defaultExchangeProvider = 0x7b285955DdcbAa597155968f9c4e901bb4c99263;

    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant wstUSR = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055;
    address constant resolv = 0x4956b52aE2fF65D74CA2d61207523288e4528f96;

    uint256 constant weth_wstETH_Expiry = 90 days + 1;
    uint256 constant wstETH_weETH_Expiry = 90 days + 1;
    uint256 constant sUSDS_USDe_Expiry = 90 days + 1;
    uint256 constant sUSDe_USDT_Expiry = 90 days + 1;
    uint256 constant wstUSR_resolv_Expiry = 60 days;

    uint256 constant weth_wstETH_ARP = 0.3698630135 ether;
    uint256 constant wstETH_weETH_ARP = 0.4931506847 ether;
    uint256 constant sUSDS_USDe_ARP = 0.9863013697 ether;
    uint256 constant sUSDe_USDT_ARP = 0.4931506847 ether;
    uint256 constant wstUSR_resolv_ARP = 0.8219178082 ether;

    uint256 constant weth_wstETH_ExchangeRate = 1.192057609 ether;
    uint256 constant wstETH_weETH_ExchangeRate = 0.8881993472 ether;
    uint256 constant sUSDS_USDe_ExchangeRate = 0.9689922481 ether;
    uint256 constant sUSDe_USDT_ExchangeRate = 0.8680142355 ether;
    uint256 constant wstUSR_resolv_ExchangeRate = 1.092925197 ether;

    uint256 constant weth_wstETH_RedemptionFee = 0.2 ether;
    uint256 constant wstETH_weETH_RedemptionFee = 0.2 ether;
    uint256 constant sUSDS_USDe_RedemptionFee = 0.2 ether;
    uint256 constant sUSDe_USDT_RedemptionFee = 0.2 ether;
    uint256 constant wstUSR_resolv_RedemptionFee = 0.2 ether;

    uint256 constant weth_wstETH_RepurchaseFee = 0.23 ether;
    uint256 constant wstETH_weETH_RepurchaseFee = 0.3 ether;
    uint256 constant sUSDS_USDe_RepurchaseFee = 0.61 ether;
    uint256 constant sUSDe_USDT_RepurchaseFee = 0.3 ether;
    uint256 constant wstUSR_resolv_RepurchaseFee = 0.76 ether;

    uint256 constant weth_wstETH_AmmBaseFee = 0.018 ether;
    uint256 constant wstETH_weETH_AmmBaseFee = 0.025 ether;
    uint256 constant sUSDS_USDe_AmmBaseFee = 0.049 ether;
    uint256 constant sUSDe_USDT_AmmBaseFee = 0.025 ether;
    uint256 constant wstUSR_resolv_AmmBaseFee = 0.041 ether;

    uint256 constant weth_wstETH_FeesSplit = 0 ether;
    uint256 constant wstETH_weETH_FeesSplit = 10 ether;
    uint256 constant sUSDS_USDe_FeesSplit = 10 ether;
    uint256 constant sUSDe_USDT_FeesSplit = 10 ether;
    uint256 constant wstUSR_resolv_FeesSplit = 10 ether;

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

        setupMarket(resolv, wstUSR, wstUSR_resolv_Expiry, wstUSR_resolv_ARP, wstUSR_resolv_ExchangeRate);
        configureFees(
            resolv,
            wstUSR,
            wstUSR_resolv_ARP,
            wstUSR_resolv_Expiry,
            wstUSR_resolv_RedemptionFee,
            wstUSR_resolv_RepurchaseFee,
            wstUSR_resolv_AmmBaseFee,
            wstUSR_resolv_FeesSplit
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

        config.issueNewDs(id, block.timestamp + 3 hours);
        console.log("New DS issued for pair");

        uint8 raDecimals = ERC20(raToken).decimals();

        console.log("ID                      : ", Strings.toHexString(uint256(Id.unwrap(id))));
        console.log("paToken                 : ", paToken);
        console.log("raToken                 : ", raToken);
        console.log("RA Decimals             : ", raDecimals);
        console.log("ARP                     : ", percentage(initialARP), "%");
        console.log("Expiry                  : ", expiryPeriod / 1 days, "days");
        console.log("exchangeRate            : ", percentage(exchangeRate));
        console.log("Decay Rate              :  0");
        console.log("Rollover period         : ", block.timestamp + 7200, "timestamp");
        console.log("AMM liquidation deadline: ", block.timestamp + 30 minutes, "timestamp");

        // vm.startPrank(0xc7Bfd896cc6A8BF1D09486Dd08f590691b20C2Ff);
        uint256 depositAmount = TransferHelper.normalizeDecimals(0.1 ether, 18, raDecimals);
        ERC20(raToken).approve(address(moduleCore), depositAmount);
        moduleCore.depositLv(id, depositAmount, 0, 0);

        // vm.startPrank(deployer);
        (address ct,) = moduleCore.swapAsset(id, 1);
        (uint256 raReserve, uint256 ctReserve) = hook.getReserves(raToken, ct);

        console.log("RA Reserve              : ", raReserve);
        console.log("CT Reserve              : ", ctReserve);

        uint256 initialDsPrice = 1e18 - (raReserve * 1e18) / ctReserve;
        console.log("Initial DS Price Raw    : ", initialDsPrice);
        console.log("Initial DS Price        : ", formatDecimals(initialDsPrice));
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

    // Main function to convert number to string with 18 decimal places
    function formatDecimals(uint256 number) public pure returns (string memory) {
        // Convert to string first
        string memory numStr = uint2str(number);
        uint256 length = bytes(numStr).length;

        // If number is less than 1e18, we need to pad with leading zeros
        if (length < 18) {
            numStr = padZeros(numStr, 18 - length);
        }

        // Insert decimal point
        return insertDecimalPoint(numStr, 18);
    }

    // Helper function to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            k = k - 1;
            uint8 temp = uint8(48 + j % 10);
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            j /= 10;
        }
        str = string(bstr);
    }

    // Helper function to pad zeros at the start
    function padZeros(string memory input, uint256 zeros) internal pure returns (string memory) {
        bytes memory paddedBytes = new bytes(zeros + bytes(input).length);

        // Add leading zeros
        for (uint256 i = 0; i < zeros; i++) {
            paddedBytes[i] = bytes1("0");
        }

        // Copy original number
        bytes memory inputBytes = bytes(input);
        for (uint256 i = 0; i < inputBytes.length; i++) {
            paddedBytes[i + zeros] = inputBytes[i];
        }

        return string(paddedBytes);
    }

    // Helper function to insert decimal point
    function insertDecimalPoint(string memory input, uint256 decimals) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        uint256 length = inputBytes.length;

        if (length <= decimals) {
            return input;
        }

        bytes memory outputBytes = new bytes(length + 1);
        uint256 decimalPosition = length - decimals;

        for (uint256 i = 0; i < decimalPosition; i++) {
            outputBytes[i] = inputBytes[i];
        }

        // Insert decimal point
        outputBytes[decimalPosition] = ".";

        // Copy rest of the number
        for (uint256 i = decimalPosition; i < length; i++) {
            outputBytes[i + 1] = inputBytes[i];
        }

        return string(outputBytes);
    }
}
