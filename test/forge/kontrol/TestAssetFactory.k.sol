pragma solidity ^0.8.24;

import {AssetFactory} from "../../../contracts/core/assets/AssetFactory.sol";

import "forge-std/Test.sol";
import {KontrolCheats} from "lib/kontrol-cheatcodes/src/KontrolCheats.sol";

contract TestAssetFactory is AssetFactory, Test, KontrolCheats {

    constructor() {
        kevm.symbolicStorage(address(this));

        bytes32 initializeSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

        vm.store(address(this), initializeSlot, bytes32(0));
    }

}