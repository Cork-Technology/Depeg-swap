import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import {
  Address,
  formatEther,
  parseEther,
  verifyTypedData,
  WalletClient,
} from "viem";

export function nowTimestampInSeconds() {
  return Math.floor(Date.now() / 1000);
}

export function expiry(withinSeconds: number) {
  return nowTimestampInSeconds() + withinSeconds;
}

export async function getSigners() {
  const signers = await hre.viem.getWalletClients();
  const defaultSigner = signers.shift()!;

  return {
    signers,
    defaultSigner,
  };
}

export async function deployAssetFactory() {
  const { defaultSigner } = await getSigners();
  const contract = await hre.viem.deployContract("AssetFactory", [], {
    client: {
      wallet: defaultSigner,
    },
  });

  await contract.write.initialize();

  return {
    contract,
  };
}

export async function deployModuleCore(factory: Address) {
  const { defaultSigner } = await getSigners();
  const mathLib = await hre.viem.deployContract("MathHelper");

  const contract = await hre.viem.deployContract("ModuleCore", [factory], {
    client: {
      wallet: defaultSigner,
    },
    libraries: {
      MathHelper: mathLib.address,
    },
  });

  return {
    contract,
  };
}

export type InitializeNewPsmArg = {
  psmCore: Address;
  pa: Address;
  ra: Address;
  wa: Address;
};

export async function initializeNewPSm(arg: InitializeNewPsmArg) {
  const { defaultSigner } = await getSigners();
  const contract = await hre.viem.getContractAt("ModuleCore", arg.psmCore);

  await contract.write.initialize([arg.pa, arg.ra, arg.wa], {
    account: defaultSigner.account,
  });

  const events = await contract.getEvents.Initialized({
    pa: arg.pa,
    ra: arg.ra,
  });

  return {
    ModuleId: events[0].args.id,
  };
}

export type IssueNewSwapAssetsArg = {
  psmCore: Address;
  ra: Address;
  pa: Address;
  expiry: number;
  factory: Address;
  wa: Address;
};

export async function mintRa(ra: Address, to: Address, amount: bigint) {
  const raContract = await hre.viem.getContractAt("DummyERCWithMetadata", ra);
  await raContract.write.mint([to, amount]);
}

export async function issueNewSwapAssets(arg: IssueNewSwapAssetsArg) {
  const factory = await hre.viem.getContractAt("AssetFactory", arg.factory);
  await factory.write.deploySwapAssets([
    arg.ra,
    arg.pa,
    arg.wa,
    arg.psmCore,
    BigInt(arg.expiry),
  ]);

  const ctDsEvents = await factory.getEvents.AssetDeployed({
    wa: arg.wa,
  });

  const ct = ctDsEvents[0].args.ct!;
  const ds = ctDsEvents[0].args.ds!;

  const { defaultSigner } = await getSigners();

  const contract = await hre.viem.getContractAt("ModuleCore", arg.psmCore);
  const ModuleId = await contract.read.getId([arg.pa, arg.ra]);
  await contract.write.issueNewDs([ModuleId, BigInt(arg.expiry), ct, ds], {
    account: defaultSigner.account,
  });

  const events = await contract.getEvents.Issued({
    ModuleId,
    expiry: BigInt(arg.expiry),
  });

  return {
    ct: events[0].args.ct,
    ds: events[0].args.ds,
    dsId: events[0].args.dsId,
    ModuleId,
    expiry: BigInt(arg.expiry),
  };
}

export const DUMMY_PA_NAME = "PA-TOKEN";
export const DUMMY_PA_TOKEN = "PTKN";
export const DUMMY_RA_NAME = "RA-TOKEN";
export const DUMMY_RA_TOKEN = "RTKN";

/**
 * deploy pa and ra
 */
export async function deployBackedAssets() {
  const { defaultSigner } = await getSigners();

  const pa = await hre.viem.deployContract(
    "DummyERCWithMetadata",
    [DUMMY_PA_NAME, DUMMY_PA_TOKEN],
    {
      client: {
        wallet: defaultSigner,
      },
    }
  );

  const ra = await hre.viem.deployContract(
    "DummyERCWithMetadata",
    [DUMMY_RA_NAME, DUMMY_RA_TOKEN],
    {
      client: {
        wallet: defaultSigner,
      },
    }
  );

  return {
    pa,
    ra,
  };
}

export type CreateWaArg = {
  factory: Address;
  ra: Address;
};

export async function createWa(arg: CreateWaArg) {
  const { defaultSigner } = await getSigners();
  const contract = await hre.viem.getContractAt("AssetFactory", arg.factory);

  await contract.write.deployWrappedAsset([arg.ra], {
    account: defaultSigner.account,
  });

  const events = await contract.getEvents.WrappedAssetDeployed({
    ra: arg.ra,
  });

  return events[0].args.wa;
}

export type PermitArg = {
  signer: WalletClient;
  erc20contractAddress: string;
  psmAddress: string;
  amount: bigint;
  deadline: bigint;
};

export async function permit(arg: PermitArg) {
  const contractName = await hre.viem
    .getContractAt("IERC20Metadata", arg.erc20contractAddress as Address)
    .then((contract) => contract.read.name());

  const nonces = await hre.viem
    .getContractAt("IERC20Permit", arg.erc20contractAddress as Address)
    .then((contract) =>
      contract.read.nonces([arg.signer.account!.address as Address])
    );

  // set the Permit type parameters
  const types = {
    Permit: [
      {
        name: "owner",
        type: "address",
      },
      {
        name: "spender",
        type: "address",
      },
      {
        name: "value",
        type: "uint256",
      },
      {
        name: "nonce",
        type: "uint256",
      },
      {
        name: "deadline",
        type: "uint256",
      },
    ],
  };

  // set the Permit type values
  const values = {
    owner: arg.signer.account!.address,
    spender: arg.psmAddress,
    value: arg.amount,
    nonce: nonces,
    deadline: arg.deadline,
  };

  // sign the Permit type data with the deployer's private key
  const sig = await arg.signer.signTypedData({
    domain: {
      chainId: hre.network.config.chainId!,
      name: contractName,
      verifyingContract: arg.erc20contractAddress as Address,
      version: "1",
    },
    account: arg.signer.account?.address as Address,
    types: types,
    primaryType: "Permit",
    message: values,
  });

  return sig;
}

export async function onlyPsmCoreWithFactory() {
  const factory = await deployAssetFactory();
  const moduleCore = await deployModuleCore(factory.contract.address);

  return {
    factory,
    moduleCore,
  };
}

export async function ModuleCoreWithInitializedPsm() {
  const { factory, moduleCore: psmCore } = await onlyPsmCoreWithFactory();
  const { pa, ra } = await backedAssets();
  const wa = await createWa({
    factory: factory.contract.address,
    ra: ra.address,
  });

  const { ModuleId } = await initializeNewPSm({
    psmCore: psmCore.contract.address,
    pa: pa.address,
    ra: ra.address,
    wa: wa!,
  });

  return {
    factory,
    psmCore,
    pa,
    ra,
    wa: await hre.viem.getContractAt("WrappedAsset", wa!),
    ModuleId: ModuleId!,
  };
}

export async function backedAssets() {
  return await deployBackedAssets();
}

// async function fixture
