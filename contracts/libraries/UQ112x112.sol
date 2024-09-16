pragma solidity ^0.8.24;

/**
 * @title UQ112x112 Library Contract
 * @author Cork Team
 * @notice UQ112x112 Library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
 * @notice range: [0, 2**112 - 1]
 * @notice resolution: 1 / 2**112
 */
library UQ112x112 {
    uint224 internal constant Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
