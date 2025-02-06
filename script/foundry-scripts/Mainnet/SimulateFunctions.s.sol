pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
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

    CorkConfig public config = CorkConfig(0xa20e3D0CCFa98f5dA170f86682b652EcaadE7888);
    ModuleCore public moduleCore = ModuleCore(0xf63B2E90DB4F128Fee825B052dF0D6064D6974A7);
    RouterState public routerState = RouterState(0x8D2E77aA31e4f956B3573503d52e5005e97913ac);
    address public exchangeProvider = 0xEa68408e974e4AEA1c40eCc38614493b513d2A63;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

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

    uint256 constant weth_wstETH_ARP = 1.5 ether;
    uint256 constant wstETH_weETH_ARP = 2 ether;
    uint256 constant sUSDS_USDe_ARP = 4 ether;
    uint256 constant sUSDe_USDT_ARP = 2 ether;

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

    uint256 constant weth_wstETH_AmmBaseFee = 0.08 ether;
    uint256 constant wstETH_weETH_AmmBaseFee = 0.1 ether;
    uint256 constant sUSDS_USDe_AmmBaseFee = 0.2 ether;
    uint256 constant sUSDe_USDT_AmmBaseFee = 0.1 ether;

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
        // Market[1] memory markets = [weth_wstETH_market];

        for (uint256 i = 0; i < markets.length; i++) {
            Market memory market = markets[i];
            Id marketId = moduleCore.getId(
                market.peggedAsset, market.redemptionAsset, market.arp, market.expiryInterval, exchangeProvider
            );

            uint256 dsId = moduleCore.lastDsId(marketId);
            (address ct, address ds) = moduleCore.swapAsset(marketId, dsId);

            uint256 lvDepositAmt = 5000;
            depositLv(market, marketId, lvDepositAmt);

            uint256 psmDepositAmt = 100;
            depositPsm(market, marketId, psmDepositAmt);

            uint256 redeemAmt = 5;
            redeemRaWithDsPa(market, marketId, dsId, redeemAmt, ds);

            returnRaWithCtDs(market, marketId, redeemAmt, ds, ct);

            // redeemLv(market, marketId, redeemAmt, ct);

            uint256 swapAmt = 1;
            swapDsForRa(market, marketId, dsId, swapAmt, ds);

            swapRaForDs(market, marketId, dsId, swapAmt);
        }

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function depositPsm(Market memory market, Id marketId, uint256 depositAmt) public {
        uint256 decimals = ERC20(market.redemptionAsset).decimals();
        depositAmt = depositAmt * 10 ** decimals;
        ERC20(market.redemptionAsset).approve(address(moduleCore), depositAmt);
        moduleCore.depositPsm(marketId, depositAmt);
    }

    function depositLv(Market memory market, Id marketId, uint256 depositAmt) public {
        uint256 decimals = ERC20(market.redemptionAsset).decimals();
        depositAmt = depositAmt * 10 ** decimals;
        ERC20(market.redemptionAsset).approve(address(moduleCore), depositAmt);
        moduleCore.depositLv(marketId, depositAmt, 0, 0);
    }

    function redeemRaWithDsPa(Market memory market, Id marketId, uint256 dsId, uint256 redeemAmt, address ds) public {
        uint256 decimals = ERC20(market.peggedAsset).decimals();
        redeemAmt = redeemAmt * 10 ** decimals;
        IERC20(market.peggedAsset).safeIncreaseAllowance(address(moduleCore), redeemAmt);

        decimals = ERC20(ds).decimals();
        ERC20(ds).approve(address(moduleCore), redeemAmt * 10 ** decimals);

        moduleCore.redeemRaWithDsPa(marketId, dsId, redeemAmt);
    }

    function returnRaWithCtDs(Market memory market, Id marketId, uint256 redeemAmt, address ds, address ct) public {
        uint256 decimals = ERC20(ds).decimals();
        redeemAmt = redeemAmt * 10 ** decimals;
        ERC20(ds).approve(address(moduleCore), redeemAmt);

        decimals = ERC20(ct).decimals();
        ERC20(ct).approve(address(moduleCore), redeemAmt);
        moduleCore.returnRaWithCtDs(marketId, redeemAmt);
    }

    function redeemLv(Market memory market, Id marketId, uint256 redeemAmt, address lv) public {
        uint256 decimals = ERC20(lv).decimals();
        redeemAmt = redeemAmt * 10 ** decimals;
        ERC20(lv).approve(address(moduleCore), redeemAmt);
        moduleCore.redeemEarlyLv(IVault.RedeemEarlyParams(marketId, redeemAmt, 0, block.timestamp + 1 days, 0, 0, 0));
    }

    function swapDsForRa(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt, address ds) public {
        uint256 decimals = ERC20(ds).decimals();
        swapAmt = swapAmt * 10 ** decimals;
        ERC20(ds).approve(address(routerState), swapAmt);
        routerState.swapDsforRa(marketId, dsId, swapAmt, 0);
    }

    function swapRaForDs(Market memory market, Id marketId, uint256 dsId, uint256 swapAmt) public {
        uint256 decimals = ERC20(market.redemptionAsset).decimals();
        swapAmt = swapAmt * 10 ** decimals;
        ERC20(market.redemptionAsset).approve(address(routerState), swapAmt);
        IDsFlashSwapCore.BuyAprroxParams memory buyApprox =
            IDsFlashSwapCore.BuyAprroxParams(108, 108, 1 ether, 1 gwei, 1 gwei, 0.01 ether);
        IDsFlashSwapCore.OffchainGuess memory offchainguess =
            IDsFlashSwapCore.OffchainGuess({initialBorrowAmount: swapAmt, afterSoldBorrowAmount: 0});
        routerState.swapRaforDs(marketId, dsId, swapAmt, 0, buyApprox, offchainguess);
    }
}
