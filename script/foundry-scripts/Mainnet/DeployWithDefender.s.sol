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
import {
    Defender,
    ApprovalProcessResponse,
    DefenderDeploy,
    DefenderOptions
} from "openzeppelin-foundry-upgrades/Defender.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployProtectedUnit is Script {
    uint256 public pk = vm.envUint("PRIVATE_KEY");
    address public deployer = vm.addr(pk);
    address public multisig = 0x8724f0884FFeF34A73084F026F317b903C6E9d06;

    address public moduleCore = 0x257dB16f013a9e7061baE32A9807497eCD72d9Ce; // moduleCore address
    address public config = 0x257dB16f013a9e7061baE32A9807497eCD72d9Ce; // config address
    address public flashswapRouter = 0x257dB16f013a9e7061baE32A9807497eCD72d9Ce; // flashswaprouter address

    function run() public {
        vm.startBroadcast(pk);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        console.log("Deployer                        : ", deployer);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");

        ApprovalProcessResponse memory upgradeApprovalProcess = Defender.getUpgradeApprovalProcess();
        if (upgradeApprovalProcess.via == address(0)) {
            revert(
                string.concat(
                    "Upgrade approval process with id ",
                    upgradeApprovalProcess.approvalProcessId,
                    " has no assigned address"
                )
            );
        }

        // For non-upgradeable contract
        DefenderOptions memory defenderOpts;
        defenderOpts.salt = "1004";
        defenderOpts.useDefenderDeploy = true;

        // constructor arguments
        bytes memory constructorData = abi.encode(moduleCore, config, flashswapRouter);

        address protectedUnitFactory = DefenderDeploy.deploy("ProtectedUnitFactory.sol", constructorData, defenderOpts);
        console.log("Deployed ProtectedUnitFactory : ", protectedUnitFactory);

        defenderOpts.salt = "1005";
        address protectedUnitRouter = DefenderDeploy.deploy("ProtectedUnitRouter.sol", "", defenderOpts);
        console.log("Deployed ProtectedUnitRouter : ", protectedUnitRouter);

        CorkConfig(config).setProtectedUnitFactory(protectedUnitFactory);
        console.log("ProtectedUnitFactory configured in Config");

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }
}
