import "./../../Helper.sol";

contract whitelistTest is Helper {
    uint256 amount = 1 ether;

    address constant DUMMY_LIQUIDATOR_ADDRESS = address(420);

    function setUp() external {
        vm.startPrank(DEFAULT_ADDRESS);

        deployModuleCore();
    }

    function test_whitelist() external {
        corkConfig.whitelist(DUMMY_LIQUIDATOR_ADDRESS);

        vm.warp(block.timestamp + 7 days);

        bool isWhitelisted = corkConfig.isLiquidationWhitelisted(DUMMY_LIQUIDATOR_ADDRESS);
        vm.assertEq(isWhitelisted, true);
    }

    function test_notWhitelistBefore7Days() external {
        corkConfig.whitelist(DUMMY_LIQUIDATOR_ADDRESS);

        bool isWhitelisted = corkConfig.isLiquidationWhitelisted(DUMMY_LIQUIDATOR_ADDRESS);
        vm.assertEq(isWhitelisted, false);
    }

    function test_blackList() external {
        corkConfig.whitelist(DUMMY_LIQUIDATOR_ADDRESS);

        vm.warp(block.timestamp + 7 days);

        corkConfig.blacklist(DUMMY_LIQUIDATOR_ADDRESS);

        bool isWhitelisted = corkConfig.isLiquidationWhitelisted(DUMMY_LIQUIDATOR_ADDRESS);
        vm.assertEq(isWhitelisted, false);
    }
}
