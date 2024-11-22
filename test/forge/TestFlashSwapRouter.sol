pragma solidity ^0.8.24;

import "./../../contracts/core/flash-swaps/FlashSwapRouter.sol";

/// @title TestFlashSwapRouter Contract, used for testing FlashSwapRouter contract, mostly here for getter functions
contract TestFlashSwapRouter is RouterState {
    constructor() RouterState() {}

    // ------------------------------------------------------------ Getters ------------------------------ 
    function getAssetPair(Id id,uint256 dsId) external view returns (AssetPair memory) {
        return reserves[id].ds[dsId];
    }

    function getReserveSellPressurePercentage(Id id) external view returns (uint256) {
        return reserves[id].reserveSellPressurePercentage;
    }

    function getHiyaCumulated(Id id) external view returns (uint256) {
        return reserves[id].hiyaCumulated;
    }

    function getVhiyaCumulated(Id id) external view returns (uint256) {
        return reserves[id].vhiyaCumulated;
    }

    function getDecayDiscountRateInDays(Id id) external view returns (uint256) {
        return reserves[id].decayDiscountRateInDays;
    }

    function getRolloverEndInBlockNumber(Id id) external view returns (uint256) {
        return reserves[id].rolloverEndInBlockNumber;
    }

    function getHiya(Id id) external view returns (uint256) {
        return reserves[id].hiya;
    }

}
