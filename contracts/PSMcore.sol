// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./libraries/PSMLib.sol";
import "./libraries/PSMKeyLib.sol";
import "./interfaces/IERC20Metadata.sol";

contract PsmCore {
    using PSMLibrary for PSMLibrary.State;
    using PsmKeyLibrary for PsmKey;

    /// @notice Emitted when a new PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    event Initialized(PsmId indexed id, address indexed pa, address indexed ra);

    mapping(PsmId => PSMLibrary.State) public modules;

    constructor() {}

    function initialize(address pa, address ra) external {
        PsmKey memory key = PsmKeyLibrary.initalize(pa, ra);
        PsmId id = key.toId();

        (string memory _pa, string memory _ra) = (
            IERC20Metadata(pa).symbol(),
            IERC20Metadata(ra).symbol()
        );
        string memory pairname = string(abi.encodePacked(_pa, "-", _ra));

        modules[id].initialize(key, pairname);

        emit Initialized(id, pa, ra);
    }
}
