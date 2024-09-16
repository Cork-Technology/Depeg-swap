pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Funder {
    IERC20 public cETH;
    mapping(address=> bool) isFunded;

    constructor(address _cETH) {
        cETH = IERC20(_cETH);
    }

    function fundUsers(address[] memory users, uint256 sepoliaAmt, uint256 cEthAmt) public {
        cETH.transferFrom(msg.sender, address(this), cEthAmt * users.length);
        for(uint256 i;i<users.length;i++){
            if(!isFunded[users[i]]){
                payable(users[i]).transfer(sepoliaAmt);
                cETH.transfer(users[i],cEthAmt);
                isFunded[users[i]]=true;
            }        
        }
    }

    function fundEveryUsers(address[] memory users, uint256 sepoliaAmt, uint256 cEthAmt) public {
        cETH.transferFrom(msg.sender, address(this), cEthAmt * users.length);
        for(uint256 i;i<users.length;i++){
            payable(users[i]).transfer(sepoliaAmt);
            cETH.transfer(users[i],cEthAmt);
            isFunded[users[i]]=true;
        }
    }

    function withdrawETH() external {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No Ether available to withdraw");
        payable(msg.sender).transfer(contractBalance);
    }

    receive() external payable {}
}
