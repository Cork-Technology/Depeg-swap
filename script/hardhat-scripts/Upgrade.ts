import { ethers, upgrades } from "hardhat";
import "@openzeppelin/hardhat-defender";
import dotenv from "dotenv";

async function main() {

    const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  
    const privateKey = process.env.PRIVATE_KEY;
  
    const signer = new ethers.Wallet(privateKey, provider);
    
    console.log("Signer address:", await signer.getAddress());

    // Get the contract factory
    const AssetNewImpl = await ethers.getContractFactory("Asset", signer);

    const PROXY_ADDRESS = ""; // proxy address

    try {
          const upgraded = await upgrades.upgradeProxy(
            "0x7c9CF1E9C0c9b07Fe8b53908eA667753Fb307FC7",
            AssetNewImpl,
            { constructorArgs: [
                      // pass all the arg in constructor 
            ] }
        );

        await upgraded.deployed();
        console.log("Proxy upgraded successfully");
        
        console.log("Upgrade transaction mined");

    } catch (error) {
        console.error("Error during upgrade:", error);
        throw error;
    }
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

