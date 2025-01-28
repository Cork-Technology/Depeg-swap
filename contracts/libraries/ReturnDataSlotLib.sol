pragma solidity ^0.8.24;

library ReturnDataSlotLib {
    // keccak256("RETURN")
    bytes32 public constant RETURN_SLOT = 0xb28124349b5a89ededaa96175a0b225363cf060aaa28ecb54f00fe1cc09eb9de;

    // keccak256("REFUNDED")
    bytes32 public constant REFUNDED_SLOT = 0x0ae202c5d1ff9dcd4329d24acbf3bddff6279ad182d19d899440adb36d927795;

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
