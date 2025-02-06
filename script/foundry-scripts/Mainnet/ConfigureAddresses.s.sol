pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CorkConfig} from "../../../contracts/core/CorkConfig.sol";
import {ModuleCore} from "../../../contracts/core/ModuleCore.sol";
import {Id} from "../../../contracts/libraries/Pair.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AssetFactory} from "../../../contracts/core/assets/AssetFactory.sol";
import {RouterState} from "../../../contracts/core/flash-swaps/FlashSwapRouter.sol";
import {Liquidator} from "../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {ProtectedUnit} from "../../../contracts/core/assets/ProtectedUnit.sol";
import {ProtectedUnitFactory} from "../../../contracts/core/assets/ProtectedUnitFactory.sol";
import {ProtectedUnitRouter} from "../../../contracts/core/assets/ProtectedUnitRouter.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {CorkHook, LiquidityToken} from "Cork-Hook/CorkHook.sol";
import {Withdrawal} from "../../../contracts/core/Withdrawal.sol";

contract ConfigureAddressesScript is Script {
    AssetFactory public assetFactory = AssetFactory(0x5fCA6b54e7033e18c1663C5D07C9125FE6ACa55C);
    CorkConfig public config = CorkConfig(0xa20e3D0CCFa98f5dA170f86682b652EcaadE7888);
    ModuleCore public moduleCore = ModuleCore(0xf63B2E90DB4F128Fee825B052dF0D6064D6974A7);
    RouterState public flashswapRouter = RouterState(0x8D2E77aA31e4f956B3573503d52e5005e97913ac);
    PoolManager public poolManager = PoolManager(0x0690dE6C169bC97f67Fa2e043332e68ab0eA8165);
    CorkHook public hook = CorkHook(0x58Fc79db69e45A5C7f8Fe31AB4D8BC8C39352a88);
    LiquidityToken public liquidityToken = LiquidityToken(0xA1838ce4edBd09616276938F045C17a74Ec23671);
    Liquidator public liquidator = Liquidator(0xae46FF13fcA921BB3125Ec2849f2e8847D97432B);
    ProtectedUnitFactory public protectedUnitFactory = ProtectedUnitFactory(0x0E0815588f5879692727646b173f3632798EC730);
    ProtectedUnitRouter public protectedUnitRouter = ProtectedUnitRouter(0x7C5C3745E621C5859e998Cb656CF7D683eeBa771);
    Withdrawal public withdrawal = Withdrawal(0xad2897687ab49138e1a33C47791fD987f54bD25B);

    address public defaultExchangeProvider = 0xEa68408e974e4AEA1c40eCc38614493b513d2A63;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                        : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        config.setModuleCore(address(moduleCore));
        config.setFlashSwapCore(address(flashswapRouter));
        config.setHook(address(hook));
        config.setProtectedUnitFactory(address(protectedUnitFactory));
        config.setTreasury(deployer);
        config.setWithdrawalContract(address(withdrawal));
        console.log("Contracts configured in Config");

        flashswapRouter.setModuleCore(address(moduleCore));
        flashswapRouter.setHook(address(hook));
        console.log("Contracts configured in Modulecore");

        vm.stopBroadcast();
    }
}
