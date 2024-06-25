import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("AssetFactory", (m) => {
  const singer = m.getAccount(0);

  const deployer = m.getAccount(1);
  const contract = m.contract("AssetFactory");

  return { contract };
});
