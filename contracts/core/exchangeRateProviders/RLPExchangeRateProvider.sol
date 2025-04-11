// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IErrors} from "../../interfaces/IErrors.sol";
import {
    IRLPExchangeRateProvider,
    IUSRPriceOracle,
    IRLPPriceOracle
} from "../../interfaces/exchangeRateProvider/IRLPExchangeRateProvider.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Id} from "../../libraries/Pair.sol";

/**
 * @title RLP ExchangeRateProvider Contract
 * @author Cork Team
 * @notice Separate contract for providing exchange rate for wstUSR:RLP pairs
 */
contract RLPExchangeRateProvider is IErrors, IRLPExchangeRateProvider {
    /// @notice Address of wstUSR token
    address public immutable WST_USR;
    /// @notice Address of USR price storage contract
    address public immutable USR_PRICE_ORACLE;
    /// @notice Address of RLP price storage contract
    address public immutable RLP_PRICE_ORACLE;

    /*
     * @notice Constructor for initializing the exchange rate provider
     * @param _wstUsr Address of wstUSR token
     * @param _usr_price_oracle Address of USR price storage contract
     * @param _rlp_price_oracle Address of RLP price storage contract
     */
    constructor(address _wstUsr, address _usr_price_oracle, address _rlp_price_oracle) {
        if (_wstUsr == address(0) || _usr_price_oracle == address(0) || _rlp_price_oracle == address(0)) {
            revert IErrors.ZeroAddress();
        }
        WST_USR = _wstUsr;
        USR_PRICE_ORACLE = _usr_price_oracle;
        RLP_PRICE_ORACLE = _rlp_price_oracle;
    }

    /// @notice Returns the exchange rate of the wstUSR:RLP pair
    function rate() external view returns (uint256) {
        return _calculateExchangeRate();
    }

    /* 
     * @notice Returns the exchange rate of the wstUSR:RLP pair for a given pair id
     * @dev This function is overriden for handling rate function calls in psmLibrary
     * @param id The id of the pair
     */
    function rate(Id id) external view returns (uint256) {
        return _calculateExchangeRate();
    }

    function _calculateExchangeRate() internal view returns (uint256) {
        // Convert 1 wstUSR to USR amount
        uint256 usrAmount = IERC4626(WST_USR).convertToAssets(1 ether);

        // Get USR price
        (uint256 usrPrice,,,) = IUSRPriceOracle(USR_PRICE_ORACLE).lastPrice();

        // Get RLP price
        (uint256 rlpPrice,) = IRLPPriceOracle(RLP_PRICE_ORACLE).lastPrice();

        // exchange rate = (usrAmount * usrPrice) / rlpPrice
        return (usrAmount * usrPrice) / rlpPrice;
    }
}
