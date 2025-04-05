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
        vm.startBroadcast(pk);
        vm.pauseGasMetering();

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        Market[4] memory markets = [weth_wstETH_market, wstETH_weETH_market, sUSDS_USDe_market, sUSDe_USDT_market];

        for (uint256 i = 0; i < markets.length; i++) {
            Market memory market = markets[i];
            Id marketId = moduleCore.getId(
                market.peggedAsset, market.redemptionAsset, market.arp, market.expiryInterval, exchangeProvider
            );

            uint256 dsId = moduleCore.lastDsId(marketId);
            (address ct, address ds) = moduleCore.swapAsset(marketId, dsId);
            address lv = moduleCore.lvAsset(marketId);

            uint256 lvDepositAmt = 5000;
            depositLv(market, marketId, lvDepositAmt);

            uint256 psmDepositAmt = 100;
            depositPsm(market, marketId, psmDepositAmt);

            uint256 redeemAmt = 5;
            redeemRaWithDsPa(market, marketId, dsId, redeemAmt, ds);

            returnRaWithCtDs(market, marketId, redeemAmt, ds, ct);

            redeemLv(market, marketId, redeemAmt, lv);

            uint256 swapAmt = 1;
            swapDsForRa(market, marketId, dsId, swapAmt, ds);

            swapRaForDs(market, marketId, dsId, swapAmt);

            swapRaCtTokens(market, marketId, swapAmt, ct);
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
        ERC20(ds).approve(address(routerState), swapAmt);
        routerState.swapDsforRa(marketId, dsId, swapAmt, 0);
    }

    function swapRaForDs(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt) public {
        swapAmt = convertToDecimals(market.redemptionAsset, swapAmt);
        ERC20(market.redemptionAsset).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory buyApprox =
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 1 ether, 1 gwei, 1 gwei, 0.01 ether);
        IDsFlashSwapCore.OffchainGuess memory offchainguess = IDsFlashSwapCore.OffchainGuess({borrow: swapAmt});
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
