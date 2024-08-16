// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

library PermitChecker {
    function supportsPermit(address token) internal view returns (bool) {
        return _hasNonces(token) && _hasDomainSeparator(token);
    }

    function _hasNonces(address token) internal view returns (bool) {
        try IERC20Permit(token).nonces(address(0)) returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    function _hasDomainSeparator(address token) internal view returns (bool) {
        try IERC20Permit(token).DOMAIN_SEPARATOR() returns (bytes32) {
            return true;
        } catch {
            return false;
        }
    }
}
