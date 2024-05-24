// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WrappedAsset is ERC20Permit, ERC20Wrapper {
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
        ERC20Permit(
            string(
                abi.encodePacked(PREFIX, IERC20Metadata(_underlying).symbol())
            )
        )
    {}

    function decimals()
        public
        view
        virtual
        override(ERC20, ERC20Wrapper)
        returns (uint8)
    {
        return this.decimals();
    }

    function wrap(uint256 amount) external {
        depositFor(_msgSender(), amount);
        emit Wrapped(msg.sender, amount);
    }

    function unwrap(uint256 amount) external {
        withdrawTo(_msgSender(), amount);
        emit UnWrapped(msg.sender, amount);
    }
}
