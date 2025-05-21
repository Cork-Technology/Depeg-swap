// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

library ReturnDataSlotLib {
    // keccak256("SELL")
    bytes32 public constant RETURN_SLOT_SELL = 0x46e2aa85b4ea4837644e46fe22acb44743da12e349006c0093a61f6bf0967602;

    // keccak256("BUY")
    bytes32 public constant RETURN_SLOT_BUY = 0x8e9b148654316179bd45e9ec5f0b575ae8288e79df16d7be748ec9a9bdca8b4c;

    // keccak256("REFUNDED")
    bytes32 public constant REFUNDED_SLOT = 0x0ae202c5d1ff9dcd4329d24acbf3bddff6279ad182d19d899440adb36d927795;

    // keccak256("DS_FEE_AMOUNT")
    bytes32 public constant DS_FEE_AMOUNT = 0x2edcf68d3b1bfd48ba1b97a39acb4e9553bc609ae5ceef6b88a0581565dba754;

    // keccak256("DS_FEE_PERCENTAGE")
    bytes32 public constant DS_FEE_PERCENTAGE = 0xd7398119f47d6f8967a859c111a043862f21ce0f6a433f21fca432ec6f693ff3;

    function increase(bytes32 slot, uint256 _value) internal {
        uint256 prev = get(slot);

        set(slot, prev + _value);
    }

    function set(bytes32 slot, uint256 _value) private {
        assembly {
            tstore(slot, _value)
        }
    }

    function get(bytes32 slot) internal view returns (uint256 _value) {
        assembly {
            _value := tload(slot)
        }
    }

    function clear(bytes32 slot) internal {
        assembly {
            tstore(slot, 0)
        }
    }
}
