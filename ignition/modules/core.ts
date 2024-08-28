import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { flashSwapMath, mathHelper, vaultLib } from "./lib";
import { uniV2Factory, uniV2router } from "./uniV2";
import moduleCore from "../../artifacts/contracts/core/ModuleCore.sol/ModuleCore.json";

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

export const ModuleCore = buildModule("ModuleCore", (m) => {
  const { MathHelper } = m.useModule(mathHelper);
  const { VaultLibrary } = m.useModule(vaultLib);

  const _assetFactory = m.getParameter("assetFactory");
  const _uniV2Factory = m.getParameter("uniV2Factory");
  const _flashSwapRouter = m.getParameter("flashSwapRouter");
  const _uniV2Router = m.getParameter("uniV2Router");
  const _corkConfig = m.getParameter("corkConfig");
  const _baseFee = m.getParameter("psmBaseFeeRedemption");

  const contract = m.contract(
    "ModuleCore",
    moduleCore,
    [
      _assetFactory,
      _uniV2Factory,
      _flashSwapRouter,
      _uniV2Router,
      _corkConfig,
      _baseFee,
    ],
    {
      libraries: {
        MathHelper: MathHelper,
        VaultLibrary: VaultLibrary,
      },
    }
  );

  return {
    ModuleCore: contract,
  };
});
