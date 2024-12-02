// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/core/Psm.sol";
import "../../contracts/libraries/State.sol";
import "../../contracts/libraries/Pair.sol";

contract PsmCoreTest is Test {
    PsmCore psmCore;
    Id mockId;

    function setUp() public {
        // Deploying the PsmCore contract
        psmCore = new PsmCoreImplementation();
       mockId = Id.wrap(bytes32(uint256(1))); 
    }

    function testUpdateRate() public {
        // Arrange
        uint256 newRate = 200e18;
        vm.startPrank(address(this)); 

        // Act
        psmCore.updateRate(mockId, newRate);

        // Assert
        uint256 currentRate = psmCore.exchangeRate(mockId);
        assertEq(currentRate, newRate, "Rate update failed");

        vm.stopPrank();
    }

    function testRepurchaseFee() public {
        // Arrange
        uint256 expectedFee = 5e16; 
        vm.mockCall(
            address(psmCore),
            abi.encodeWithSelector(State.repurchaseFeePercentage.selector),
            abi.encode(expectedFee)
        );

        // Act
        uint256 fee = psmCore.repurchaseFee(mockId);

        // Assert
        assertEq(fee, expectedFee, "Repurchase fee mismatch");
    }

    function testRepurchase() public {
        // Arrange
        uint256 amount = 100e18;
        uint256 expectedReceivedPa = 95e18;
        uint256 expectedFee = 5e18;
        vm.mockCall(
            address(psmCore),
            abi.encodeWithSelector(State.repurchase.selector),
            abi.encode(0, expectedReceivedPa, 0, 5e16, expectedFee, 1e18)
        );

        // Act
        (uint256 dsId, uint256 receivedPa, uint256 receivedDs, uint256 feePercentage, uint256 fee, uint256 exchangeRates) =
            psmCore.repurchase(mockId, amount);

        // Assert
        assertEq(receivedPa, expectedReceivedPa, "Incorrect PA received");
        assertEq(fee, expectedFee, "Incorrect fee calculated");
    }

    function testAvailableForRepurchase() public {
        // Arrange
        uint256 expectedPa = 1000e18;
        uint256 expectedDs = 500e18;
        uint256 expectedDsId = 1;
        vm.mockCall(
            address(psmCore),
            abi.encodeWithSelector(State.availableForRepurchase.selector),
            abi.encode(expectedPa, expectedDs, expectedDsId)
        );

        // Act
        (uint256 pa, uint256 ds, uint256 dsId) = psmCore.availableForRepurchase(mockId);

        // Assert
        assertEq(pa, expectedPa, "Incorrect PA available");
        assertEq(ds, expectedDs, "Incorrect DS available");
        assertEq(dsId, expectedDsId, "Incorrect DS ID");
    }
}

// Implementation stub for testing
contract PsmCoreImplementation is PsmCore {
    function onlyConfig() internal view override {}
    function getRouterCore() internal view override returns (address) {
        return address(this);
    }
    function getAmmRouter() internal view override returns (address) {
        return address(this);
    }
}
