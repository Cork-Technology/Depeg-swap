pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {CorkHook} from "Cork-Hook/CorkHook.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Id, PairLibrary} from "../../../contracts/libraries/Pair.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "../../../contracts/interfaces/IVault.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDsFlashSwapCore} from "../../../contracts/interfaces/IDsFlashSwapRouter.sol";

struct Market {
    address redemptionAsset;
    address peggedAsset;
    uint256 expiryInterval;
    uint256 arp;
    uint256 redemptionFee;
    uint256 repurchaseFee;
    uint256 ammBaseFee;
}

contract SimulateScript is Script {
    using SafeERC20 for IERC20;

    CorkConfig public config = CorkConfig(0x03D16DdA7b4447e02f5ca0a6724205040eadE1D6);
    ModuleCore public moduleCore = ModuleCore(0xc6c5880d3a6097Cb7905986fEAFbC30B533fA39D);
    RouterState public routerState = RouterState(0x14B04A7ff48099DB786c5d63b199AccD108E2c90);
    CorkHook public corkHook = CorkHook(0x337f3d2771EC8D351a88FeCc0F3cBaa52C3FAA88);
    address public exchangeProvider = 0x3737b26D5cEDc3B0ca0A803054cE3baEf029bc15;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    address ceth = 0x0000000237805496906796B1e767640a804576DF;
    address cusd = 0x1111111A3Ae9c9b133Ea86BdDa837E7E796450EA;
    address wamuETH = 0x22222228802B45325E0b8D0152C633449Ab06913;
    address bsETH = 0x33333335a697843FDd47D599680Ccb91837F59aF;
    address mlETH = 0x44444447386435500C5a06B167269f42FA4ae8d4;
    address svbUSD = 0x5555555eBBf30a4b084078319Da2348fD7B9e470;
    address fedUSD = 0x666666685C211074C1b0cFed7e43E1e7D8749E43;
    address omgUSD = 0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0;
    address weth = 0xd0073Cc17aAf764a948c262f410B6957B369C0cd;
    address wstETH = 0xBfEDFEc502CAd6D815Edc947Ba0Fd5A31D8ef5e1;

    uint256 constant wamuETHExpiry = 3.5 days;
    uint256 constant bsETHExpiry = 3.5 days;
    uint256 constant mlETHExpiry = 1 days;
    uint256 constant svbUSDExpiry = 3.5 days;
    uint256 constant fedUSDExpiry = 3.5 days;
    uint256 constant omgUSDExpiry = 0.5 days;
    uint256 constant weth_wstETHExpiry = 90 days + 1;

    uint256 constant wamuETH_ARP = 1.285 ether;
    uint256 constant bsETH_ARP = 6.428 ether;
    uint256 constant mlETH_ARP = 7.5 ether;
    uint256 constant svbUSD_ARP = 8.571 ether;
    uint256 constant fedUSD_ARP = 4.285 ether;
    uint256 constant omgUSD_ARP = 5.1 ether;
    uint256 constant weth_wstETH_ARP = 0.3698630135 ether;

    uint256 constant wamuETH_RedemptionFee = 0.2 ether;
    uint256 constant bsETH_RedemptionFee = 0.2 ether;
    uint256 constant mlETH_RedemptionFee = 0.2 ether;
    uint256 constant svbUSD_RedemptionFee = 0.2 ether;
    uint256 constant fedUSD_RedemptionFee = 0.2 ether;
    uint256 constant omgUSD_RedemptionFee = 0.08 ether;
    uint256 constant weth_wstETH_RedemptionFee = 0.2 ether;

    uint256 constant wamuETH_RepurchaseFee = 0.75 ether;
    uint256 constant bsETH_RepurchaseFee = 0.75 ether;
    uint256 constant mlETH_RepurchaseFee = 0.75 ether;
    uint256 constant svbUSD_RepurchaseFee = 0.75 ether;
    uint256 constant fedUSD_RepurchaseFee = 0.75 ether;
    uint256 constant omgUSD_RepurchaseFee = 0.75 ether;
    uint256 constant weth_wstETH_RepurchaseFee = 0.23 ether;

    uint256 constant wamuETH_AmmBaseFee = 0.15 ether;
    uint256 constant bsETH_AmmBaseFee = 0.3 ether;
    uint256 constant mlETH_AmmBaseFee = 0.3 ether;
    uint256 constant svbUSD_AmmBaseFee = 0.3 ether;
    uint256 constant fedUSD_AmmBaseFee = 0.15 ether;
    uint256 constant omgUSD_AmmBaseFee = 0.3 ether;
    uint256 constant weth_wstETH_AmmBaseFee = 0.018 ether;

    Market ceth_wamuETH_market = Market(
        ceth, wamuETH, wamuETHExpiry, wamuETH_ARP, wamuETH_RedemptionFee, wamuETH_RepurchaseFee, wamuETH_AmmBaseFee
    );
    Market wamuETH_bsETH_market =
        Market(wamuETH, bsETH, bsETHExpiry, bsETH_ARP, bsETH_RedemptionFee, bsETH_RepurchaseFee, bsETH_AmmBaseFee);
    Market bsETH_mlETH_market =
        Market(bsETH, mlETH, mlETHExpiry, mlETH_ARP, mlETH_RedemptionFee, mlETH_RepurchaseFee, mlETH_AmmBaseFee);
    Market fedUSD_svbUSD_market =
        Market(fedUSD, svbUSD, svbUSDExpiry, svbUSD_ARP, svbUSD_RedemptionFee, svbUSD_RepurchaseFee, svbUSD_AmmBaseFee);
    Market cusd_fedUSD_market =
        Market(cusd, fedUSD, fedUSDExpiry, fedUSD_ARP, fedUSD_RedemptionFee, fedUSD_RepurchaseFee, fedUSD_AmmBaseFee);
    Market svbUSD_omgUSD_market =
        Market(svbUSD, omgUSD, omgUSDExpiry, omgUSD_ARP, omgUSD_RedemptionFee, omgUSD_RepurchaseFee, omgUSD_AmmBaseFee);
    Market weth_wstETH_market = Market(
        weth,
        wstETH,
        weth_wstETHExpiry,
        weth_wstETH_ARP,
        weth_wstETH_RedemptionFee,
        weth_wstETH_RepurchaseFee,
        weth_wstETH_AmmBaseFee
    );

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        vm.pauseGasMetering();

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Market[7] memory markets = [
        //     ceth_wamuETH_market,
        //     wamuETH_bsETH_market,
        //     bsETH_mlETH_market,
        //     fedUSD_svbUSD_market,
        //     cusd_fedUSD_market,
        //     svbUSD_omgUSD_market,
        //     weth_wstETH_market
        // ];
        Market[1] memory markets = [weth_wstETH_market];

        for (uint256 i = 0; i < markets.length; i++) {
            Market memory market = markets[i];
            Id marketId = moduleCore.getId(
                market.peggedAsset, market.redemptionAsset, market.arp, market.expiryInterval, exchangeProvider
            );
            // config.updateReserveSellPressurePercentage(marketId, 2 ether);

            uint256 dsId = moduleCore.lastDsId(marketId);
            (address ct, address ds) = moduleCore.swapAsset(marketId, dsId);
            address lv = moduleCore.lvAsset(marketId);

            // uint256 lvDepositAmt = 5000;
            // depositLv(market, marketId, lvDepositAmt);

            uint256 psmDepositAmt = 100;
            // depositPsm(market, marketId, psmDepositAmt);

            // uint256 redeemAmt = 5;
            // redeemRaWithDsPa(market, marketId, dsId, redeemAmt, ds);

            // returnRaWithCtDs(market, marketId, redeemAmt, ds, ct);

            // redeemLv(market, marketId, redeemAmt, lv);

            uint256 swapAmt = 1;
            swapRaForDs(market, marketId, dsId, swapAmt);
            swapDsForRa(market, marketId, dsId, swapAmt, ds);
            // uint256 amountOut = corkHook.getAmountOut(market.redemptionAsset, ct, false, 1 ether);
            // console.log("CT price Before : ", amountOut / 1 ether, ".", amountOut % 1 ether);

            swapRaForDs(market, marketId, dsId, swapAmt);

            // amountOut = corkHook.getAmountOut(market.redemptionAsset, ct, false, 1 ether);
            // console.log("CT price After : ", amountOut / 1 ether, ".", amountOut % 1 ether);
            // swapRaCtTokens(market, marketId, swapAmt, ct);
        }

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function depositPsm(Market memory market, Id marketId, uint256 depositAmt) public {
        depositAmt = convertToDecimals(market.redemptionAsset, depositAmt);
        ERC20(market.redemptionAsset).approve(address(moduleCore), depositAmt);
        moduleCore.depositPsm(marketId, depositAmt);
    }

    function depositLv(Market memory market, Id marketId, uint256 depositAmt) public {
        depositAmt = convertToDecimals(market.redemptionAsset, depositAmt);
        ERC20(market.redemptionAsset).approve(address(moduleCore), depositAmt);
        moduleCore.depositLv(marketId, depositAmt, 0, 0, 0);
    }

    function redeemRaWithDsPa(Market memory market, Id marketId, uint256 dsId, uint256 redeemAmt, address ds) public {
        redeemAmt = convertToDecimals(market.peggedAsset, redeemAmt);
        IERC20(market.peggedAsset).safeIncreaseAllowance(address(moduleCore), redeemAmt);

        uint256 decimals = ERC20(ds).decimals();
        ERC20(ds).approve(address(moduleCore), redeemAmt * 10 ** decimals);

        moduleCore.redeemRaWithDsPa(marketId, dsId, redeemAmt);
    }

    function returnRaWithCtDs(Market memory market, Id marketId, uint256 redeemAmt, address ds, address ct) public {
        redeemAmt = convertToDecimals(ds, redeemAmt);
        ERC20(ds).approve(address(moduleCore), redeemAmt);
        ERC20(ct).approve(address(moduleCore), redeemAmt);
        moduleCore.returnRaWithCtDs(marketId, redeemAmt);
    }

    function redeemLv(Market memory market, Id marketId, uint256 redeemAmt, address lv) public {
        redeemAmt = convertToDecimals(lv, redeemAmt);
        ERC20(lv).approve(address(moduleCore), redeemAmt);
        moduleCore.redeemEarlyLv(IVault.RedeemEarlyParams(marketId, redeemAmt, 0, block.timestamp + 1 days, 0, 0, 0));
    }

    function swapDsForRa(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt, address ds) public {
        swapAmt = convertToDecimals(ds, swapAmt);
        swapAmt = 4 ether;
        ERC20(ds).approve(address(routerState), swapAmt);
        routerState.swapDsforRa(marketId, dsId, swapAmt, 0);
    }

    function swapRaForDs(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt) public {
        swapAmt = convertToDecimals(market.redemptionAsset, swapAmt);
        swapAmt = 0.1 ether;
        ERC20(market.redemptionAsset).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory buyApprox =
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 1 ether, 1 gwei, 1 gwei, 0.01 ether);
        IDsFlashSwapCore.OffchainGuess memory offchainguess = IDsFlashSwapCore.OffchainGuess(0, 0);
        routerState.swapRaforDs(marketId, dsId, swapAmt, 0, buyApprox, offchainguess);
    }

    function swapRaCtTokens(Market memory market, Id marketId, uint256 swapAmt, address ct) public {
        uint256 inputAmt = convertToDecimals(market.redemptionAsset, swapAmt);
        uint256 amountOut = corkHook.getAmountOut(market.redemptionAsset, ct, true, inputAmt);
        uint256 inputOut = corkHook.getAmountIn(market.redemptionAsset, ct, true, amountOut);
        ERC20(market.redemptionAsset).approve(address(corkHook), inputOut + inputOut / 100000);
        corkHook.swap(market.redemptionAsset, ct, 0, amountOut, bytes(""));
        console.log("Swapped RA with CT");

        inputAmt = convertToDecimals(ct, swapAmt);
        amountOut = corkHook.getAmountOut(market.redemptionAsset, ct, false, inputAmt);
        inputOut = corkHook.getAmountIn(market.redemptionAsset, ct, false, amountOut);
        ERC20(ct).approve(address(corkHook), inputOut + inputOut / 100000);
        corkHook.swap(market.redemptionAsset, ct, amountOut, 0, bytes(""));
        console.log("Swapped CT with RA");
    }

    function convertToDecimals(address token, uint256 value) public view returns (uint256) {
        uint256 decimals = ERC20(token).decimals();
        return value * 10 ** decimals;
    }
}
