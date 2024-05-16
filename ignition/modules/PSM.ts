import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const PsmModule = buildModule("PsmModule", (m) => {
  const contract = m.contract("PsmCore");

  return { contract };
});

export default PsmModule;
