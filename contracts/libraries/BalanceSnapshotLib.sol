import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.24;

library BalancesSnapshot {
    function takeSnapshot(address token) internal {
        bytes32 slot = _computeSlot(token);
        uint256 _balance = IERC20(token).balanceOf(address(this));

        assembly ("memory-safe") {
            tstore(slot, _balance)
        }
    }

    function getSnapshot(address token) internal view returns (uint256 _balance) {
        bytes32 slot = _computeSlot(token);

        assembly ("memory-safe") {
            _balance := tload(slot)
        }
    }

    function getDifferences(address token) internal view returns (uint256 _difference) {
        bytes32 slot = _computeSlot(token);
        uint256 _balance = IERC20(token).balanceOf(address(this));

        assembly ("memory-safe") {
            _difference := sub(_balance, tload(slot))
        }
    }

    function _computeSlot(address token) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(token));
    }
}
