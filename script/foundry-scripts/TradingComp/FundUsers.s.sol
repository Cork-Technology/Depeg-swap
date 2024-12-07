pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Funder} from "../../../contracts/tc_utils/Funder.sol";

contract FundUsersScript is Script {
    Funder public funder;
    IERC20 public cETH;
    IERC20 public cUSD;

    address public ceth = vm.envAddress("WETH");
    address public cusd = vm.envAddress("CUSD");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    uint256 cEthAmt = 100 ether;
    uint256 cUSDAmt = 250_000 ether;
    uint256 sepoliaEthAmt = 0.1 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        cETH = IERC20(ceth);
        cUSD = IERC20(cusd);
        funder = Funder(payable(0xf179831E60B55a02E351d18070fa50859F9Fd189));

        address[] memory users = loadAddressesFromFile("addresses.txt");
        fundUsers(users);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function fundUsers(address[] memory users) public {
        cETH.approve(address(funder), users.length * cEthAmt);
        cUSD.approve(address(funder), users.length * cUSDAmt);
        payable(address(funder)).transfer(users.length * sepoliaEthAmt);
        funder.fundUsers(users, sepoliaEthAmt, cEthAmt, cUSDAmt);
    }

    function loadAddressesFromFile(string memory fileName) internal returns (address[] memory) {
        string memory fileContent = vm.readFile(fileName);

        string[] memory addressStrings = vm.split(fileContent, "\n");

        address[] memory users = new address[](addressStrings.length);

        for (uint256 i = 0; i < addressStrings.length; i++) {
            users[i] = vm.parseAddress(addressStrings[i]);
        }
        return users;
    }
}
