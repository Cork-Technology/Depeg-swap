import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import UNIV2FACTORY from "../../test/helper/ext-abi/uni-v2-factory.json";
import UNIV2ROUTER from "../../test/helper/ext-abi/uni-v2-router.json";
import { artifacts } from "hardhat";
import { Artifact } from "hardhat/types";
import { flashSwapRouter } from "./core";

export const uniV2router = buildModule("UniV2Router", (m) => {
  const routerArtifact: Artifact = {
    _format: "hh-sol-artifact-1",
    abi: UNIV2ROUTER.abi,
    bytecode: UNIV2ROUTER.evm.bytecode.object,
    linkReferences: UNIV2ROUTER.evm.bytecode.linkReferences,
    contractName: "UniV2Router",
    deployedBytecode: UNIV2ROUTER.evm.deployedBytecode.object,
    deployedLinkReferences: UNIV2ROUTER.evm.deployedBytecode.linkReferences,
    sourceName: "UniV2Router.sol",
  };

  const contract = m.contract<typeof UNIV2FACTORY.abi>(
    "UniV2Router",
    routerArtifact
  );

  return { UniV2Router: contract };
});

export const uniV2Factory = buildModule("uniV2Factory", (m) => {
  const flashSwap = m.useModule(flashSwapRouter);
  const feeToSetter = m.getAccount(0);

  const routerArtifact: Artifact = {
    _format: "hh-sol-artifact-1",
    abi: UNIV2FACTORY.abi,
    bytecode: UNIV2FACTORY.evm.bytecode.object,
    linkReferences: UNIV2FACTORY.evm.bytecode.linkReferences,
    contractName: "UniV2Factory",
    deployedBytecode: UNIV2FACTORY.evm.deployedBytecode.object,
    deployedLinkReferences: UNIV2FACTORY.evm.deployedBytecode.linkReferences,
    sourceName: "UniV2Factory.sol",
  };

  const contract = m.contract<typeof UNIV2FACTORY.abi>(
    "UniV2Factory",
    routerArtifact,
    [feeToSetter, flashSwap]
  );

  return { UniV2Router: contract };
});

export const dummyWETH = buildModule("DummyWETH", (m) => {
  const contract = m.contract("DummyWETH");
  return { DummyWETH: contract };
});
