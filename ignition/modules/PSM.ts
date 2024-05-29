import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import assetFactory from "./AssetFactory";

const PsmModule = buildModule("PsmModule", (m) => {
  const { contract } = m.useModule(assetFactory);

  const elle = m.contract("PsmCore", [contract]);
  return { contract };
});

export default PsmModule;
