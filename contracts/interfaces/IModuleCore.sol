// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title IModuleCore Interface
 * @author Cork Team
 * @notice IModuleCore interface for ModuleCore contract
 */
interface IModuleCore {
    function lastDsId(Id id) external view returns (uint256 dsId);

    function valueLocked(Id id, bool ra) external view returns (uint256);

    function valueLocked(Id id, uint256 dsId, bool ra) external view returns (uint256);
}
