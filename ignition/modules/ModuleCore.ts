import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import assetFactory from "./AssetFactory";

const ModuleCore = buildModule("ModuleCore", (m) => {
  const { contract } = m.useModule(assetFactory);

  const mathHelper = m.library("MathHelper");
  const module = m.contract("ModuleCore", [contract], {
    libraries: {
      MathHelper: mathHelper,
    },
  });

  m.call(contract, "initialize", [module]);

  return { module };
});

export default ModuleCore;
