pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

library TransferHelper {
    uint8 constant TARGET_DECIMALS = 18;

    function normalizeDecimals(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter)
        internal
        pure
        returns (uint256)
    {
        // If we need to increase the decimals
        if (decimalsBefore > decimalsAfter) {
            // Then we shift right the amount by the number of decimals
            amount = amount / 10 ** (decimalsBefore - decimalsAfter);
            // If we need to decrease the number
        } else if (decimalsBefore < decimalsAfter) {
            // then we shift left by the difference
            amount = amount * 10 ** (decimalsAfter - decimalsBefore);
        }
        // If nothing changed this is a no-op
        return amount;
    }

    function tokenNativeDecimalsToFixed(uint256 amount, IERC20Metadata token) public view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, decimals, TARGET_DECIMALS);
    }

    function tokenNativeDecimalsToFixed(uint256 amount, address token) public view returns (uint256) {
        return tokenNativeDecimalsToFixed(amount, IERC20Metadata(token));
    }

    function fixedToTokenNativeDecimals(uint256 amount, IERC20Metadata token) public view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, TARGET_DECIMALS, decimals);
    }

    function fixedToTokenNativeDecimals(uint256 amount, address token) public view returns (uint256) {
        return fixedToTokenNativeDecimals(amount, IERC20Metadata(token));
    }

    function transferNormalize(ERC20 token, address _to, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransfer(token, _to, amount);
    }

    function transferNormalize(address token, address _to, uint256 _amount) internal returns (uint256 amount) {
        return transferNormalize(ERC20(token), _to, _amount);
    }

    function transferFromNormalize(ERC20 token, address _from, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransferFrom(token, _from, address(this), amount);
    }

    function transferFromNormalize(address token, address _from, uint256 _amount) internal returns (uint256 amount) {
        return transferFromNormalize(ERC20(token), _from, _amount);
    }

    function burnNormalize(ERC20Burnable token, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        token.burn(amount);
    }

    function burnNormalize(address token, uint256 _amount) internal returns (uint256 amount) {
        return burnNormalize(ERC20Burnable(token), _amount);
    }
}
