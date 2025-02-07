pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICST {
    function deposit(uint256 amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TransferTokensScript is Script {
    using SafeERC20 for ERC20;

    uint256 public pk = vm.envUint("PRIVATE_KEY");
    uint256 transferAmt = 100;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 decimals;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);
        transferTokens(0x0000000000000000000000000000000000000000);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function transferTokens(address user) public {
        payable(user).transfer(0.1 ether);

        decimals = ERC20(weth).decimals();
        ERC20(weth).safeTransfer(user, transferAmt * 10 ** decimals);

        decimals = ERC20(wstETH).decimals();
        ERC20(wstETH).safeTransfer(user, transferAmt * 10 ** decimals);

        decimals = ERC20(weETH).decimals();
        ERC20(weETH).safeTransfer(user, transferAmt * 10 ** decimals);

        decimals = ERC20(sUSDS).decimals();
        ERC20(sUSDS).safeTransfer(user, transferAmt * 10 ** decimals);

        decimals = ERC20(USDe).decimals();
        ERC20(USDe).safeTransfer(user, transferAmt * 10 ** decimals);

        decimals = ERC20(sUSDe).decimals();
        ERC20(sUSDe).safeTransfer(user, transferAmt * 10 ** decimals);

        decimals = ERC20(USDT).decimals();
        ERC20(USDT).safeTransfer(user, transferAmt * 10 ** decimals);
    }
}
