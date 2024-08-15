import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { flashSwapMath, mathHelper } from "./lib";

export const assetFactory = buildModule("AssetFactory", (m) => {
  const contract = m.contract("AssetFactory");

  return { assetFactory: contract };
});

export const corkConfig = buildModule("CorkConfig", (m) => {
  const contract = m.contract("CorkConfig");
  return { CorkConfig: contract };
});

export const flashSwapRouter = buildModule("FlashSwapRouter", (m) => {
  const { MathHelper } = m.useModule(mathHelper);
  const { SwapperMathLibrary } = m.useModule(flashSwapMath);

  const contract = m.contract("RouterState", [], {
    libraries: {
      MathHelper,
      SwapperMathLibrary,
    },
  });

  return { FlashSwapRouter: contract };
});
