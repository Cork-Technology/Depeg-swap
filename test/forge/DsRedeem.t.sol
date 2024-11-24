pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Helper} from "./Helper.sol";
import {DummyWETH} from "./../../contracts/dummy/DummyWETH.sol";
import "./../../contracts/core/assets/Asset.sol";
import {Id, Pair, PairLibrary} from "./../../contracts/libraries/Pair.sol";
import "./../../contracts/interfaces/IPSMcore.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../../contracts/libraries/MathHelper.sol";

contract VaultRedeemTest is Helper {
    DummyWETH internal ra;
    DummyWETH internal pa;
    Id public currencyId;

    uint256 public DEFAULT_DEPOSIT_AMOUNT = 10000 ether;
    uint256 redemptionFeePercentage = 10 ether;

    uint256 public dsId;

    address public lv;
    address user2 = address(30);
    address ds;
    uint256 _expiry = 1 days;

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();

        (ra, pa, currencyId) = initializeAndIssueNewDs(_expiry, redemptionFeePercentage);
        vm.deal(DEFAULT_ADDRESS, type(uint256).max);

        ra.deposit{value: type(uint128).max}();
        pa.deposit{value: type(uint128).max}();

        // 10000 for psm 10000 for LV
        ra.approve(address(moduleCore), type(uint256).max);

        moduleCore.depositPsm(currencyId, DEFAULT_DEPOSIT_AMOUNT);

        // save initial data
        lv = assetFactory.getLv(address(ra), address(pa), _expiry);
        dsId = moduleCore.lastDsId(currencyId);
        (, ds) = moduleCore.swapAsset(currencyId, 1);
        Asset(ds).approve(address(moduleCore), type(uint256).max);
        pa.approve(address(moduleCore), type(uint256).max);
    }

    function test_getId() external {
        address ceth = 0x6D9DD9fB3a1bd4fB0310DD5CE871AB1A75aa0197;

        address wamuETH = 0x442b2A6b0b7f0728fE72E381f9eC65cbE92EF92d;
        uint256 ceth_WamuExpire = 3.5 days;
        Id ceth_wamuETHId = moduleCore.getId(wamuETH, ceth, ceth_WamuExpire);
        console.log("ceth_wamuETHId");
        console.logBytes32(Id.unwrap(ceth_wamuETHId));

        address bsETH = 0x52480170Cf53f76bABACE04b84d3CbBd8cCfcAf2;
        uint256 wamu_BsETHxpire = 3.5 days;
        Id wamu_bsETHId = moduleCore.getId(bsETH, wamuETH, wamu_BsETHxpire);
        console.log("wamu_bsETHId");
        console.logBytes32(Id.unwrap(wamu_bsETHId));

        address mlETH = 0xBaFc88AfcF2193f326711144578B7874F1Ef1F63;
        uint256 bsETH_mlETHExpire = 1 days;
        Id bsETH_mlETHId = moduleCore.getId(mlETH, bsETH, bsETH_mlETHExpire);
        console.log("bsETH_mlETHId");
        console.logBytes32(Id.unwrap(bsETH_mlETHId));

        address CUSD = 0x647DE4ac37023E993c5b6495857a43E0566e9C7d;

        address svbUDS = 0x34F48991F54181456462349137928133d13a142f;

        address fedUSD = 0x2ca2F3872033BcA2C9BFb8698699793aED76FF94;

        address omgUSD = 0xe94E4045B69829fCf0FC9546006942130c6c9836;

        uint256 fedUSD_svbUSDEXpiry = 3.5 days;
        Id fedUSD_svbUSDId = moduleCore.getId(svbUDS, fedUSD, fedUSD_svbUSDEXpiry);
        console.log("fedUSD_svbUSDId");
        console.logBytes32(Id.unwrap(fedUSD_svbUSDId));

        uint256 cusd_fedUSDExpiry = 3.5 days;
        Id cusd_fedUSDId = moduleCore.getId(fedUSD, CUSD, cusd_fedUSDExpiry);
        console.log("cusd_fedUSDId");
        console.logBytes32(Id.unwrap(cusd_fedUSDId));

        uint256 svbUSD_omgUSDExpiry = 0.5 days;
        Id svbUSD_omgUSDId = moduleCore.getId(omgUSD, svbUDS, svbUSD_omgUSDExpiry);
        console.log("svbUSD_omgUSDId");
        console.logBytes32(Id.unwrap(svbUSD_omgUSDId));
    }

    function testFuzz_redeemDs(uint256 redeemAmount) external {
        redeemAmount = bound(redeemAmount, 0.1 ether, DEFAULT_DEPOSIT_AMOUNT);

        uint256 expectedFee = MathHelper.calculatePercentageFee(moduleCore.baseRedemptionFee(currencyId), redeemAmount);

        uint256 received;
        uint256 fee;
        (received,, fee) = moduleCore.redeemRaWithDs(currencyId, dsId, redeemAmount);
        vm.assertEq(received, redeemAmount - expectedFee);
        vm.assertEq(fee, expectedFee);
    }
}
