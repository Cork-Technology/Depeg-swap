import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const vaultLib = buildModule("VaultLib", (m) => {
  const mathHelper = m.library("MathHelper");

  const contract = m.library("VaultLibrary", {
    libraries: {
      MathHelper: mathHelper,
    },
  });

  return { VaultLibrary: contract };
});

export const psmLib = buildModule("PsmLib", (m) => {
  const contract = m.library("PsmLibrary");

  return { PsmLibrary: contract };
});

export const mathHelper = buildModule("MathHelper", (m) => {
  const contract = m.library("MathHelper");

  return { MathHelper: contract };
});

export const flashSwapMath = buildModule("FlashSwapMath", (m) => {
  const contract = m.library("SwapperMathLibrary");

  return { SwapperMathLibrary: contract };
});
