// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract TransferOwnership is Script {
   
    address public constant MULTISIG = address(0x4Dd9054FD30Be93F76C04fc478d4ba56DE93D6e7);
    
    // Replace with your actual contract addresses
    address[] public contractsToTransfer = [
        address(0x90FB52888D6101933a789F6eE1f2E20C6e33C38c),
        address(0x3b4D1DfA4C806A9c747006e5599Ec97ab7c324f2),
        address(0x806545E7CDBaCbF1ae1bB4224E0175f74cf64305),
        address(0xc2123D61D1B1B9D0cd2D2B00E269496331E83C76),
        address(0x36Eb151c00E832a7C0e6ec2A28d50A605fF436F5),
        address(0xBA35E732C35390DBcb7B7489ECeDFD660C53db5A),
        address(0xEc8d1170A0675812E50C2d3753F7da6eac2E6D5E),
        address(0x2bD1f94337ae58D7907F2b47c30d9C5Bb74A107F),
        address(0xFdd8093279CA477884824Edc5DB9Fbf7CeB53790)
    ];

    function run() external {
        require(MULTISIG != address(0), "Invalid multisig address");
        
        vm.startBroadcast();

        for (uint i = 0; i < contractsToTransfer.length; i++) {
            address contractAddress = contractsToTransfer[i];
            console.log("Transferring ownership of contract:", contractAddress);
            
            (bool success, ) = contractAddress.call(
                abi.encodeWithSignature("transferOwnership(address)", MULTISIG)
            );
            (bool successX, bytes memory data) = contractAddress.staticcall(
                abi.encodeWithSignature("owner()")
            );
            require(successX, "Getter Call failed");
            address owner = abi.decode(data, (address));
            require(success, "Ownership transfer failed");
            console.log("===============================================");
            console.log("New Owner from Call============================" , owner );
            console.log("Successfully transferred ownership to multisig:", MULTISIG);
            console.log("===============================================");
        }

        vm.stopBroadcast();
    }
}