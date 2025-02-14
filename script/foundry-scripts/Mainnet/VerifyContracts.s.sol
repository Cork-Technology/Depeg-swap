pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetFactory} from "../../../contracts/core/assets/AssetFactory.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {Liquidator} from "../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {ProtectedUnit} from "../../../contracts/core/assets/ProtectedUnit.sol";
import {ProtectedUnitFactory} from "../../../contracts/core/assets/ProtectedUnitFactory.sol";
import {ProtectedUnitRouter} from "../../../contracts/core/assets/ProtectedUnitRouter.sol";
import {CETH} from "../../../contracts/tokens/CETH.sol";
import {CUSD} from "../../../contracts/tokens/CUSD.sol";
import {CST} from "../../../contracts/tokens/CST.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {HookMiner} from "../Utils/HookMiner.sol";
import {PoolKey, Currency, CorkHook, LiquidityToken, Hooks} from "Cork-Hook/CorkHook.sol";
import {Withdrawal} from "../../../contracts/core/Withdrawal.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract VerificationScript is Script {
    AssetFactory public assetFactory;
    CorkConfig public config;
    RouterState public flashswapRouter;
    ModuleCore public moduleCore;
    PoolManager public poolManager;
    CorkHook public hook;
    LiquidityToken public liquidityToken;
    Withdrawal public withdrawal;

    address public defaultExchangeProvider;

    address constant SETTLEMENT_CONTRACT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant CREATE_2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant treasury = 0xb9EEeBa3659466d251E8A732dB2341E390AA059F;
    address constant multisig = 0x8724f0884FFeF34A73084F026F317b903C6E9d06;
    address constant deployerAdd = 0x777777727073E72Fbb3c81f9A8B88Cc49fEAe2F5;

    uint256 constant weth_wstETH_Expiry = 90 days;
    uint256 constant wstETH_weETH_Expiry = 90 days;
    uint256 constant sUSDS_USDe_Expiry = 90 days;
    uint256 constant sUSDe_USDT_Expiry = 90 days;

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

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    function setUp() public {
        assetFactory = AssetFactory(0x96E0121D1cb39a46877aaE11DB85bc661f88D5fA);
        config = CorkConfig(0xF0DA8927Df8D759d5BA6d3d714B1452135D99cFC);
        flashswapRouter = RouterState(0x55B90B37416DC0Bd936045A8110d1aF3B6Bf0fc3);
        poolManager = PoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
        liquidityToken = LiquidityToken(0x083c322aDa898F880a1d0a959A6e69081B82E5bc);
        hook = CorkHook(0x5287E8915445aee78e10190559D8Dd21E0E9Ea88);
        moduleCore = ModuleCore(0xCCd90F6435dd78C4ECCED1FA4db0D7242548a2a9);
        withdrawal = Withdrawal(0xf27e7e8A854211E030cfCd39350827CC15eFf721);
        defaultExchangeProvider = 0x7b285955DdcbAa597155968f9c4e901bb4c99263;
    }

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                        : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        // Asset Factory
        assert(assetFactory.moduleCore() == address(moduleCore));
        assert(assetFactory.owner() == multisig);

        // Cork Config
        assert(address(config.moduleCore()) == address(moduleCore));
        assert(address(config.flashSwapRouter()) == address(flashswapRouter));
        assert(address(config.hook()) == address(hook));
        assert(config.treasury() == treasury);
        assert(config.hasRole(config.DEFAULT_ADMIN_ROLE(), multisig) == true);
        assert(config.hasRole(config.MANAGER_ROLE(), multisig) == true);
        assert(config.hasRole(config.DEFAULT_ADMIN_ROLE(), deployerAdd) == false);
        assert(config.hasRole(config.MANAGER_ROLE(), deployerAdd) == false);

        // Module Core
        assert(address(moduleCore.factory()) == address(assetFactory));
        assert(address(moduleCore.getAmmRouter()) == address(hook));
        assert(address(moduleCore.getRouterCore()) == address(flashswapRouter));
        assert(address(moduleCore.getTreasuryAddress()) == address(treasury));
        assert(address(moduleCore.getWithdrawalContract()) == address(withdrawal));
        assert(moduleCore.owner() == multisig);

        // FlashSwapRouter
        assert(address(flashswapRouter.config()) == address(config));
        assert(flashswapRouter._moduleCore() == address(moduleCore));
        assert(address(flashswapRouter.hook()) == address(hook));
        assert(flashswapRouter.hasRole(flashswapRouter.DEFAULT_ADMIN_ROLE(), multisig) == true);
        assert(flashswapRouter.hasRole(flashswapRouter.CONFIG(), address(config)) == true);
        assert(flashswapRouter.hasRole(flashswapRouter.DEFAULT_ADMIN_ROLE(), deployerAdd) == false);

        // Cork Hook
        assert(hook.getPoolManager() == address(poolManager));
        assert(hook.owner() == address(config));
        console.log("Contract addresses are setup correctly");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
