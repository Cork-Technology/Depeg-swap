pragma solidity ^0.8.24;

import "./../../Helper.sol";

contract liquidatorRoleTest is Helper {
    uint256 amount = 1 ether;

    address constant DUMMY_LIQUIDATOR_ADDRESS = address(420);
    address constant DUMMY_USER_ADDRESS = address(69);

    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();
    }

    function test_grantLiquidator() external {
        corkConfig.grantLiquidatorRole(DUMMY_LIQUIDATOR_ADDRESS, DUMMY_USER_ADDRESS);
        bool result = corkConfig.isTrustedLiquidationExecutor(DUMMY_LIQUIDATOR_ADDRESS, DUMMY_USER_ADDRESS);

        vm.assertEq(result, true);
    }

    function test_revokeLiquidator() external {
        corkConfig.grantLiquidatorRole(DUMMY_LIQUIDATOR_ADDRESS, DUMMY_USER_ADDRESS);

        bool result = corkConfig.isTrustedLiquidationExecutor(DUMMY_LIQUIDATOR_ADDRESS, DUMMY_USER_ADDRESS);

        vm.assertEq(result, true);

        corkConfig.revokeLiquidatorRole(DUMMY_LIQUIDATOR_ADDRESS, DUMMY_USER_ADDRESS);

        result = corkConfig.isTrustedLiquidationExecutor(DUMMY_LIQUIDATOR_ADDRESS, DUMMY_USER_ADDRESS);

        vm.assertEq(result, false);
    }
}
