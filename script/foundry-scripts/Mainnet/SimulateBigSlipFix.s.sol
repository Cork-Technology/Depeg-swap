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
import {AssetFactory} from "../../../contracts/core/assets/AssetFactory.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Utils} from "../Utils/Utils.s.sol";

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

contract SimulateScript is Script {
    using SafeERC20 for IERC20;

    CorkConfig public config = CorkConfig(0xF0DA8927Df8D759d5BA6d3d714B1452135D99cFC);
    ModuleCore public moduleCore = ModuleCore(0xCCd90F6435dd78C4ECCED1FA4db0D7242548a2a9);
    RouterState public routerState = RouterState(0x55B90B37416DC0Bd936045A8110d1aF3B6Bf0fc3);
    CorkHook public corkHook = CorkHook(0x5287E8915445aee78e10190559D8Dd21E0E9Ea88);
    address public exchangeProvider = 0x7b285955DdcbAa597155968f9c4e901bb4c99263;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);
    address public user = 0xd85351181b3F264ee0FDFa94518464d7c3DefaDa;

    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 constant weth_wstETH_Expiry = 90 days + 1;
    uint256 constant wstETH_weETH_Expiry = 90 days + 1;
    uint256 constant sUSDS_USDe_Expiry = 90 days + 1;
    uint256 constant sUSDe_USDT_Expiry = 90 days + 1;

    uint256 constant weth_wstETH_ARP = 0.3698630135 ether;
    uint256 constant wstETH_weETH_ARP = 0.4931506847 ether;
    uint256 constant sUSDS_USDe_ARP = 0.9863013697 ether;
    uint256 constant sUSDe_USDT_ARP = 0.4931506847 ether;

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

    Market weth_wstETH_market = Market(
        weth,
        wstETH,
        weth_wstETH_Expiry,
        weth_wstETH_ARP,
        weth_wstETH_ExchangeRate,
        weth_wstETH_RedemptionFee,
        weth_wstETH_RepurchaseFee,
        weth_wstETH_AmmBaseFee
    );
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
    Market sUSDS_USDe_market = Market(
        sUSDS,
        USDe,
        sUSDS_USDe_Expiry,
        sUSDS_USDe_ARP,
        sUSDS_USDe_ExchangeRate,
        sUSDS_USDe_RedemptionFee,
        sUSDS_USDe_RepurchaseFee,
        sUSDS_USDe_AmmBaseFee
    );
    Market sUSDe_USDT_market = Market(
        sUSDe,
        USDT,
        sUSDe_USDT_Expiry,
        sUSDe_USDT_ARP,
        sUSDe_USDT_ExchangeRate,
        sUSDe_USDT_RedemptionFee,
        sUSDe_USDT_RepurchaseFee,
        sUSDe_USDT_AmmBaseFee
    );

    function setUp() public {}

    function run() public {
        vm.startPrank(0x8724f0884FFeF34A73084F026F317b903C6E9d06);
        AssetFactory factory = new AssetFactory();
        AssetFactory factoryProxy = AssetFactory(0x96E0121D1cb39a46877aaE11DB85bc661f88D5fA);
        factoryProxy.upgradeToAndCall(address(factory), bytes(""));
        console.log("Assets Factory Upgraded");

        RouterState router = new RouterState();
        routerState.upgradeToAndCall(address(router), bytes(""));
        console.log("Flash Swap Router Upgraded");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Market[4] memory markets = [weth_wstETH_market, wstETH_weETH_market, sUSDS_USDe_market, sUSDe_USDT_market];
        Market[1] memory markets = [wstETH_weETH_market];
        for (uint256 i = 0; i < markets.length; i++) {
            Market memory market = markets[i];
            Id marketId = moduleCore.getId(
                market.peggedAsset, market.redemptionAsset, market.arp, market.expiryInterval, exchangeProvider
            );

            config.updateReserveSellPressurePercentage(marketId, 50 ether);

            uint256 dsId = moduleCore.lastDsId(marketId);
            (address ct, address ds) = moduleCore.swapAsset(marketId, dsId);
            address lv = moduleCore.lvAsset(marketId);

            vm.startPrank(user);

            uint256 swapAmt = 10;
            console.log("SwapRaForDs With 50% Sell Pressure Thresold");
            swapRaForDs(market, marketId, dsId, swapAmt, ct, ds);
            console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

            console.log("");
        }

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopPrank();
    }

    function swapDsForRa(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt, address ds) public {
        swapAmt = convertToDecimals(ds, swapAmt);
        ERC20(ds).approve(address(routerState), swapAmt);
        routerState.swapDsforRa(marketId, dsId, swapAmt, 0);
    }

    function swapRaForDs(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt, address ct, address ds)
        public
    {
        console.log(
            "RA price Before    : ",
            Utils.formatEther(corkHook.getAmountOut(market.redemptionAsset, ct, false, 1 ether))
        );
        console.log(
            "CT price Before    : ", Utils.formatEther(corkHook.getAmountOut(market.redemptionAsset, ct, true, 1 ether))
        );
        console.log(
            "LV reserve Before  : ", Utils.formatEther(RouterState(address(routerState)).getLvReserve(marketId, dsId))
        );
        console.log(
            "PSM reserve Before : ", Utils.formatEther(RouterState(address(routerState)).getPsmReserve(marketId, dsId))
        );
        console.log("User RA bal Before : ", Utils.formatEther(ERC20(market.redemptionAsset).balanceOf(user)));
        console.log("User CT bal Before : ", Utils.formatEther(ERC20(ct).balanceOf(user)));
        console.log("User DS bal Before : ", Utils.formatEther(ERC20(ds).balanceOf(user)));

        {
            (uint256 raBal, uint256 ctBal) = corkHook.getReserves(market.redemptionAsset, ct);
            console.log("AMM RA bal Before  : ", Utils.formatEther(raBal));
            console.log("AMM CT bal Before  : ", Utils.formatEther(ctBal));
        }
        console.log("------------------------------");

        swapAmt = convertToDecimals(market.redemptionAsset, swapAmt);
        ERC20(market.redemptionAsset).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory buyApprox =
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 1 ether, 1 gwei, 1 gwei, 0.01 ether);
        IDsFlashSwapCore.OffchainGuess memory offchainguess = IDsFlashSwapCore.OffchainGuess({borrow: swapAmt});
        IDsFlashSwapCore.SwapRaForDsReturn memory result =
            routerState.swapRaforDs(marketId, dsId, swapAmt, 0, buyApprox, offchainguess);

        string memory raSymbol = ERC20(market.redemptionAsset).symbol();
        console.log("Swapped", raSymbol, "for DS");
        console.log("Swap Amount         : ", Utils.formatEther(swapAmt));
        console.log("Swap Amount Out     : ", Utils.formatEther(result.amountOut));
        console.log("CT Refunded         : ", Utils.formatEther(result.ctRefunded));
        console.log("Borrow              : ", Utils.formatEther(result.borrow));
        console.log("Fee                 : ", result.fee);
        console.log("reserveSellPressure : ", Utils.formatEther(result.reserveSellPressure), "%");
        console.log("------------------------------");

        console.log(
            "RA price After     : ",
            Utils.formatEther(corkHook.getAmountOut(market.redemptionAsset, ct, false, 1 ether))
        );
        console.log(
            "CT price After     : ", Utils.formatEther(corkHook.getAmountOut(market.redemptionAsset, ct, true, 1 ether))
        );
        console.log(
            "LV reserve After   : ", Utils.formatEther(RouterState(address(routerState)).getLvReserve(marketId, dsId))
        );
        console.log(
            "PSM reserve After  : ", Utils.formatEther(RouterState(address(routerState)).getPsmReserve(marketId, dsId))
        );
        console.log("User RA bal After  : ", Utils.formatEther(ERC20(market.redemptionAsset).balanceOf(user)));
        console.log("User CT bal After  : ", Utils.formatEther(ERC20(ct).balanceOf(user)));
        console.log("User DS bal After  : ", Utils.formatEther(ERC20(ds).balanceOf(user)));
        {
            (uint256 raBal, uint256 ctBal) = corkHook.getReserves(market.redemptionAsset, ct);
            console.log("AMM RA bal After   : ", Utils.formatEther(raBal));
            console.log("AMM CT bal After   : ", Utils.formatEther(ctBal));
        }
    }

    function convertToDecimals(address token, uint256 value) public view returns (uint256) {
        uint256 decimals = ERC20(token).decimals();
        return value * 10 ** decimals;
    }
}
