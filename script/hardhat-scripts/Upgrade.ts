import {defender, ethers} from "hardhat";
import   "@openzeppelin/hardhat-defender" ;

async function main(){

    const AssetNewImpl = await ethers.getContractAt("Asset","0xB0b1E68f6DDE488e6c67f46FFf20545B3f2cDC34" );
    const proposal = await defender.proposeUpgrade("0x7c9CF1E9CDc9D07Fe8b53908eA667753Fb307FC7", "AssetNewImpl");
    console.log(`Upgrade Propose with URL : ${proposal.url}`);


}
function sleep(ms: number) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
    });
  