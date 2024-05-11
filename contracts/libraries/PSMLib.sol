// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./../DepegSwap.sol";
import "./../CoverToken.sol";

library PSM {
    event Deposited(address indexed user, uint256 amount, uint256 indexed dsId);
    event Issued(
        address indexed dsAddress,
        uint256 indexed dsId,
        uint256 expiry
    );

    struct Info {
        address peggedAsset;
        address redemptionAsset;
        uint256 fee;
    }

    struct DepegSwapInfo {
        address depegSwap;
        address coverToken;
        uint256 expiryTimestamp;
    }

    struct WrappedAsset {
        address asset;
    }

    struct State {
        Info info;
        mapping(uint256 => DepegSwapInfo) ds;
        uint256 dsCount;
        uint256 lockedWa;
        uint256 freeWa;
    }

    function initialize(
        State storage self,
        address peggedAddress,
        address redemptionAddress,
        uint256 fee
    ) internal {
        self.info = Info({
            peggedAsset: peggedAddress,
            redemptionAsset: redemptionAddress,
            fee: fee
        });
    }

    function issue(
        State storage self,
        uint256 expiry,
        string memory name,
        string memory symbol
    ) internal {
        DepegSwap ds = new DepegSwap(
            string(abi.encodePacked("DS", name)),
            string(abi.encodePacked("DS", symbol))
        );

        CoverToken ct = new CoverToken(
            string(abi.encodePacked("CT", name)),
            string(abi.encodePacked("CT", symbol))
        );

        self.info = DepegSwapInfo({
            depegSwap: address(ds),
            coverToken: address(ct),
            expiryTimestamp: expiry
        });
    }

    function deposit(uint256 amount, uint256 dsId) external {}
}
