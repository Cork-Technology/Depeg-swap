// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

contract SigUtils is Test {
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline,bytes32 functionHash)");
    bytes32 public constant CUSTOM_PERMIT_TYPEHASH = 0x80b24e394b7fdf35ccd5eb8f755150927489ac082064fc8f3e9fb140f57f3725;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    struct CustomPermit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
        bytes32 functionHash;
    }

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getCutomStructHash(CustomPermit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CUSTOM_PERMIT_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline,
                _permit.functionHash
            )
        );
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getCustomTypedDataHash(CustomPermit memory _permit, bytes32 DOMAIN_SEPARATOR)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCutomStructHash(_permit)));
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit, bytes32 DOMAIN_SEPARATOR) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }

    function getCustomPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint256 pk,
        bytes32 DOMAIN_SEPARATOR,
        string memory functionName
    ) internal pure returns (bytes memory) {
        bytes32 functionHash = keccak256(bytes(functionName));
        CustomPermit memory permit = CustomPermit({
            owner: owner,
            spender: spender,
            value: value,
            nonce: nonce,
            deadline: deadline,
            functionHash: functionHash
        });

        bytes32 digest = getCustomTypedDataHash(permit, DOMAIN_SEPARATOR);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        return abi.encodePacked(r, s, v);
    }

    function getPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint256 pk,
        bytes32 DOMAIN_SEPARATOR
    ) internal pure returns (bytes memory) {
        Permit memory permit = Permit({owner: owner, spender: spender, value: value, nonce: nonce, deadline: deadline});

        bytes32 digest = getTypedDataHash(permit, DOMAIN_SEPARATOR);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        return abi.encodePacked(r, s, v);
    }
}
