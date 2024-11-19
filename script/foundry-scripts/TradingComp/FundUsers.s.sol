pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Funder} from "../../../contracts/tc_utils/Funder.sol";

contract FundUsersScript is Script {
    Funder public funder;
    IERC20 public cETH;

    address public ceth = vm.envAddress("WETH");
    uint256 public pk = vm.envUint("PRIVATE_KEY");

    uint256 cEthAmt = 10_000 ether;
    uint256 sepoliaEthAmt = 0.25 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(pk);

        cETH = IERC20(ceth);
        funder = Funder(payable(0xd301e625fAFF0C21e157f3b9154CFF44DD963728));

        address[] memory users = loadAddressesFromFile("addresses.txt");
        fundUsers(users); 
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-");
        vm.stopBroadcast();
    }

    function fundUsers(address[] memory users) public {
        cETH.approve(address(funder), users.length * cEthAmt);
        payable(address(funder)).transfer(users.length * sepoliaEthAmt);
        funder.fundUsers(users, sepoliaEthAmt, cEthAmt);
    }
    
    function loadAddressesFromFile(string memory fileName) internal returns (address[] memory) {
        string memory fileContent = vm.readFile(fileName);
        
        string[] memory addressStrings = vm.split(fileContent, "\n");
        
        address[] memory users = new address[](addressStrings.length);
        
        for (uint i = 0; i < addressStrings.length; i++) {
            users[i] = vm.parseAddress(addressStrings[i]);
        }
        return users;
    }
}
