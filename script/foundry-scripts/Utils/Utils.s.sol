pragma solidity 0.8.24;

library Utils {
    // Function to convert Wei to Ether format (string)
    function formatEther(uint256 weiValue) public pure returns (string memory) {
        return string(abi.encodePacked(uint2str(weiValue / 1e18), ".", uint2str(weiValue % 1e18)));
    }

    // Function to convert uint256 to string
    function uint2str(uint256 _i) public pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
