// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract WrappedAsset is ERC20Wrapper {
    event Wrapped(address indexed owner, uint256 amount);

    event UnWrapped(address indexed owner, uint256 amount);

    string private PREFIX = "WA-";

    constructor(
        address _underlying
    )
        ERC20(
            string(
                abi.encodePacked(PREFIX, IERC20Metadata(_underlying).name())
            ),
            string(
                abi.encodePacked(PREFIX, IERC20Metadata(_underlying).symbol())
            )
        )
        ERC20Wrapper(IERC20(_underlying))
    {}

    function wrap(uint256 amount) external {
        depositFor(_msgSender(), amount);
        emit Wrapped(msg.sender, amount);
    }

    function unwrap(uint256 amount) external {
        withdrawTo(_msgSender(), amount);
        emit UnWrapped(msg.sender, amount);
    }
}
