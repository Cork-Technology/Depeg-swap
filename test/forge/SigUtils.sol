// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

contract SigUtils is Test {

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline,bytes32 functionHash)");
    bytes32 public constant PERMIT_TYPEHASH = 0x80b24e394b7fdf35ccd5eb8f755150927489ac082064fc8f3e9fb140f57f3725;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
        bytes32 functionHash;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline, _permit.functionHash)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit, bytes32 DOMAIN_SEPARATOR) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }

    function getPermit(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline, uint256 pk, bytes32 DOMAIN_SEPARATOR, string memory functionName)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 functionHash = keccak256(bytes(functionName));
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: owner, spender: spender, value: value, nonce: nonce, deadline: deadline, functionHash: functionHash});

        bytes32 digest = getTypedDataHash(permit, DOMAIN_SEPARATOR);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        return abi.encodePacked(r, s, v);
    }
}
