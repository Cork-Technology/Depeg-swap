pragma solidity ^0.8.24;

import {Helper} from "./../../Helper.sol";
import {ProtectedUnit} from "../../../../contracts/core/assets/ProtectedUnit.sol";
import {IProtectedUnit} from "../../../../contracts/interfaces/IProtectedUnit.sol";
import {ProtectedUnitV2Mock} from "./mocks/ProtectedUnitV2Mock.sol";
import {ProtectedUnitFactory} from "../../../../contracts/core/assets/ProtectedUnitFactory.sol";
import {Liquidator} from "../../../../contracts/core/liquidators/cow-protocol/Liquidator.sol";
import {IErrors} from "../../../../contracts/interfaces/IErrors.sol";
import {DummyERCWithPermit} from "../../../../contracts/dummy/DummyERCWithPermit.sol";
import {Id} from "./../../../../contracts/libraries/Pair.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Asset} from "../../../../contracts/core/assets/Asset.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SigUtils} from "../../SigUtils.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ProtectedUnitTest is Helper {
    ProtectedUnit public protectedUnit;
    ProtectedUnitV2Mock public protectedUnitV2Impl;
    DummyERCWithPermit public dsToken;
    DummyERCWithPermit internal ra;
    DummyERCWithPermit internal pa;

    Id public currencyId;
    address public owner;
    address public user;
    string public pairName = "TEST/USD";
    uint256 public constant MINT_CAP = 1000000 ether;

    event ProtectedUnitImplUpdated(address indexed oldImpl, address indexed newImpl);
    event ProtectedUnitUpgraded(address indexed protectedUnit);
    event RenouncedUpgradeability(address indexed protectedUnit);

    function setUp() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Setup accounts
        owner = address(this);
        user = vm.addr(1);

        // Deploy implementation contract
        protectedUnitV2Impl = new ProtectedUnitV2Mock();

        // Deploy moduleCore and other dependencies
        deployModuleCore();
        (ra, pa, currencyId) = initializeAndIssueNewDsWithRaAsPermit(block.timestamp + 1 days);

        // Deploy a ProtectedUnit contract
        protectedUnit =
            ProtectedUnit(corkConfig.deployProtectedUnit(currencyId, address(pa), address(ra), pairName, MINT_CAP));
    }

    function test_ProtectedUnitInitialization() public {
        assertEq(protectedUnit.factory(), address(protectedUnitFactory));
        assertEq(address(protectedUnit.moduleCore()), address(moduleCore));
        assertEq(address(protectedUnit.config()), address(corkConfig));
        assertEq(address(protectedUnit.flashswapRouter()), address(flashSwapRouter));
        assertEq(address(protectedUnit.permit2()), address(permit2));
        assertEq(address(protectedUnit.pa()), address(pa));
        assertEq(address(protectedUnit.ra()), address(ra));
        assertEq(protectedUnit.factory(), address(protectedUnitFactory));
        assertEq(protectedUnitFactory.protectedUnitImpl(), protectedUnitImpl);
        assertEq(protectedUnitFactory.protectedUnitContracts(currencyId), address(protectedUnit));
    }

    function test_UpdateProtectedUnitImpl() public {
        // Check current implementation
        address oldImpl = protectedUnitFactory.protectedUnitImpl();

        // Expect event to be emitted
        vm.expectEmit(true, true, false, false);
        emit ProtectedUnitImplUpdated(oldImpl, address(protectedUnitV2Impl));
        protectedUnitFactory.updateProtectedUnitImpl(address(protectedUnitV2Impl));

        // Verify implementation was updated
        assertEq(protectedUnitFactory.protectedUnitImpl(), address(protectedUnitV2Impl));
    }

    function test_UpdateProtectedUnitImplRevertsForNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        protectedUnitFactory.updateProtectedUnitImpl(address(protectedUnitV2Impl));
        vm.stopPrank();
    }

    function test_UpdateProtectedUnitImplRevertsForZeroAddress() public {
        vm.expectRevert(IErrors.ZeroAddress.selector);
        protectedUnitFactory.updateProtectedUnitImpl(address(0));
    }

    function test_UpgradeProtectedUnit() public {
        // First update the implementation in the factory
        protectedUnitFactory.updateProtectedUnitImpl(address(protectedUnitV2Impl));

        // Expect event to be emitted
        vm.expectEmit(true, false, false, false);
        emit ProtectedUnitUpgraded(address(protectedUnit));

        // Upgrade the protected unit
        protectedUnitFactory.upgradeProtectedUnit(address(protectedUnit));

        // Verify the upgrade was successful by checking the new function
        ProtectedUnitV2Mock upgradedUnit = ProtectedUnitV2Mock(address(protectedUnit));
        assertEq(upgradedUnit.getVersion(), "V2");

        // Verify original state was preserved
        assertEq(upgradedUnit.mintCap(), MINT_CAP);
        assertEq(address(upgradedUnit.pa()), address(pa));
        assertEq(address(upgradedUnit.ra()), address(ra));
        assertEq(upgradedUnit.factory(), address(protectedUnitFactory));
    }

    function test_UpgradeProtectedUnitRevertsForNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        protectedUnitFactory.upgradeProtectedUnit(address(protectedUnit));
        vm.stopPrank();
    }

    function test_ProtectedUnitUpgradeRevertsForNonFactory() public {
        vm.startPrank(DEFAULT_ADDRESS);
        vm.expectRevert(IProtectedUnit.OnlyFactory.selector);
        protectedUnit.upgradeToAndCall(address(protectedUnitV2Impl), "");
        vm.stopPrank();
    }

    function test_ProtectedUnitDeploymentUsesCorrectImpl() public {
        vm.startPrank(DEFAULT_ADDRESS);

        // Update implementation in factory
        protectedUnitFactory.updateProtectedUnitImpl(address(protectedUnitV2Impl));

        (DummyERCWithPermit ra2, DummyERCWithPermit pa2, Id currencyId2) =
            initializeAndIssueNewDsWithRaAsPermit(block.timestamp + 1 days);
        address newPuAddress =
            corkConfig.deployProtectedUnit(currencyId2, address(pa2), address(ra2), "NEW/USD", MINT_CAP);

        // Verify new protected unit uses the updated implementation
        ProtectedUnitV2Mock newProtectedUnit = ProtectedUnitV2Mock(newPuAddress);
        assertEq(newProtectedUnit.getVersion(), "V2");
        vm.stopPrank();
    }

    function test_BatchUpgradeMultipleProtectedUnits() public {
        // Deploy another protected unit
        vm.startPrank(DEFAULT_ADDRESS);
        (DummyERCWithPermit ra2, DummyERCWithPermit pa2, Id currencyId2) =
            initializeAndIssueNewDsWithRaAsPermit(block.timestamp + 1 days);
        address newPuAddress =
            corkConfig.deployProtectedUnit(currencyId2, address(pa2), address(ra2), "NEW/USD", MINT_CAP);
        ProtectedUnit newProtectedUnit = ProtectedUnit(newPuAddress);

        // Update to V2 implementation
        protectedUnitFactory.updateProtectedUnitImpl(address(protectedUnitV2Impl));

        // Upgrade both protected units
        protectedUnitFactory.upgradeProtectedUnit(address(protectedUnit));
        protectedUnitFactory.upgradeProtectedUnit(address(newProtectedUnit));

        // Verify both units were upgraded
        ProtectedUnitV2Mock upgradedUnit1 = ProtectedUnitV2Mock(address(protectedUnit));
        ProtectedUnitV2Mock upgradedUnit2 = ProtectedUnitV2Mock(address(newProtectedUnit));

        assertEq(upgradedUnit1.getVersion(), "V2");
        assertEq(upgradedUnit2.getVersion(), "V2");
        vm.stopPrank();
    }

    function test_RenounceUpgradeability() public {
        vm.startPrank(DEFAULT_ADDRESS);
        vm.expectEmit(true, false, false, false);
        emit RenouncedUpgradeability(address(protectedUnit));
        protectedUnitFactory.renounceUpgradeability(address(protectedUnit));

        vm.expectRevert(IProtectedUnit.OnlyFactory.selector);
        protectedUnitFactory.upgradeProtectedUnit(address(protectedUnit));
        vm.stopPrank();
    }

    function test_RenounceUpgradeabilityRevertsForNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        protectedUnitFactory.renounceUpgradeability(address(protectedUnit));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        protectedUnitFactory.renounceUpgradeability(address(protectedUnit));
        vm.stopPrank();
    }

    function test_RenounceUpgradeabilityRevertsForAlreadyRenounced() public {
        vm.startPrank(DEFAULT_ADDRESS);
        protectedUnitFactory.renounceUpgradeability(address(protectedUnit));

        vm.expectRevert(IProtectedUnit.OnlyFactory.selector);
        protectedUnitFactory.renounceUpgradeability(address(protectedUnit));

        vm.startPrank(address(0));
        vm.expectRevert(IProtectedUnit.AlreadyRenounced.selector);
        protectedUnit.renounceUpgradeability();
        vm.stopPrank();
    }
}
