pragma solidity 0.8.24;

library Utils {
    // Function to convert Wei to Ether format (string)
    function formatEther(uint256 weiValue) public pure returns (string memory) {
        // Convert WEI to Ether by dividing by 1e18 (Ether has 18 decimal places)
        uint256 integerPart = weiValue / 1e18;
        uint256 decimalPart = weiValue % 1e18;

        // Convert integer and decimal parts to strings
        string memory integerString = uint2str(integerPart);
        string memory decimalString = uint2str(decimalPart);

        // Ensure decimal part is 18 digits by padding with leading zeros
        decimalString = padDecimal(decimalString);

        // Concatenate integer and decimal parts
        return string(abi.encodePacked(integerString, ".", decimalString));
    }

    // Convert uint256 to string
    function uint2str(uint256 _i) internal pure returns (string memory) {
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
            bstr[k] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    // Pad the decimal part to ensure it has 18 digits
    function padDecimal(string memory decimalString) internal pure returns (string memory) {
        uint256 decimalLength = bytes(decimalString).length;
        if (decimalLength < 18) {
            for (uint256 i = 0; i < 18 - decimalLength; i++) {
                decimalString = string(abi.encodePacked("0", decimalString));
            }
        }
        return decimalString;
    }
}
