import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre, { viem } from "hardhat";
import {
  Address,
  formatEther,
  GetContractReturnType,
  keccak256,
  parseEther,
  verifyTypedData,
  WalletClient,
} from "viem";
import UNIV2FACTORY from "@uniswap/v2-core/build/UniswapV2Factory.json";
import UNIV2ROUTER from "./ext-abi/uni-v2-router.json";

const DEVISOR = BigInt(1e18);

export function calculateMinimumLiquidity(amount: bigint) {
  // 1e16 is the minimum liquidity(10e3)
  const minLiquidity = amount / BigInt(1e16);

  return amount - minLiquidity;
}

export function encodeAsUQ112x112(amount: bigint) {
  return amount * BigInt(2 ** 112);
}

export function decodeUQ112x112(amount: bigint) {
  return amount / BigInt(2 ** 112);
}

export function nowTimestampInSeconds() {
  return Math.floor(Date.now() / 1000);
}

export async function computeInitHash(address: Address) {
  const client = await hre.viem.getPublicClient();
  const byteceode = await client.getBytecode({ address });
  return keccak256(`0x${byteceode}`);
}

export function toNumber(b: bigint) {
  return Number(b / DEVISOR);
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

  return {
    contract,
  };
}

export async function deployCorkConfig() {
  const { defaultSigner } = await getSigners();
  const contract = await hre.viem.deployContract("CorkConfig", [], {
    client: {
      wallet: defaultSigner,
    },
  });

  return {
    contract,
  };
}

export async function deployWeth() {
  const contract = await hre.viem.deployContract("DummyWETH");

  return {
    contract,
  };
}

export async function deployFlashSwapRouter() {
  const mathLib = await hre.viem.deployContract("SwapperMathLibrary");
  const contract = await hre.viem.deployContract("RouterState", [], {
    libraries: {
      SwapperMathLibrary: mathLib.address,
    },
  });

  return {
    contract,
  };
}

// will default use the first wallet client
export async function deployUniV2Factory() {
  const defaultSigner = await getSigners().then(
    (signers) => signers.defaultSigner
  );

  const hash = await defaultSigner.deployContract({
    abi: UNIV2FACTORY.abi,
    bytecode: `0x${UNIV2FACTORY.bytecode}`,
    account: defaultSigner.account,
    args: [defaultSigner.account.address],
  });

  const client = await hre.viem.getPublicClient();
  const receipt = await client.waitForTransactionReceipt({
    hash,
  });

  return receipt.contractAddress!;
}

export async function deployUniV2Router(
  weth: Address,
  univ2Factory: Address,
  router: Address
) {
  const defaultSigner = await getSigners().then(
    (signers) => signers.defaultSigner
  );

  const hash = await defaultSigner.deployContract({
    abi: UNIV2ROUTER.abi,
    bytecode: `0x${UNIV2ROUTER.bytecode}`,
    account: defaultSigner.account,
    args: [univ2Factory, weth, router],
  });

  const client = await hre.viem.getPublicClient();
  const receipt = await client.waitForTransactionReceipt({
    hash,
  });

  return receipt.contractAddress!;
}

export async function deployModuleCore(
  swapAssetFactory: Address,
  config: Address
) {
  const { defaultSigner } = await getSigners();
  const mathLib = await hre.viem.deployContract("MathHelper");
  const dsFlashSwapRouter = await deployFlashSwapRouter();
  const univ2Factory = await deployUniV2Factory();
  const weth = await deployWeth();
  const univ2Router = await deployUniV2Router(
    weth.contract.address,
    univ2Factory,
    dsFlashSwapRouter.contract.address
  );

  const contract = await hre.viem.deployContract(
    "ModuleCore",
    [
      swapAssetFactory,
      univ2Factory,
      dsFlashSwapRouter.contract.address,
      univ2Router,
      config,
    ],
    {
      client: {
        wallet: defaultSigner,
      },
      libraries: {
        MathHelper: mathLib.address,
      },
    }
  );

  await dsFlashSwapRouter.contract.write.initialize([contract.address]);

  return {
    contract,
    univ2Factory,
    univ2Router,
    dsFlashSwapRouter,
    weth,
  };
}

export type InitializeNewPsmArg = {
  moduleCore: Address;
  config: Address;
  pa: Address;
  ra: Address;
  lvFee: bigint;
  lvAmmWaDepositThreshold: bigint;
  lvAmmCtDepositThreshold: bigint;
};

export async function initializeNewPsmLv(arg: InitializeNewPsmArg) {
  const { defaultSigner } = await getSigners();
  const contract = await hre.viem.getContractAt("ModuleCore", arg.moduleCore);
  const configContract = await hre.viem.getContractAt("CorkConfig", arg.config);

  await configContract.write.setModuleCore([arg.moduleCore], {
    account: defaultSigner.account,
  });

  await configContract.write.initializeModuleCore(
    [
      arg.pa,
      arg.ra,
      arg.lvFee,
      arg.lvAmmWaDepositThreshold,
      arg.lvAmmCtDepositThreshold,
    ],
    {
      account: defaultSigner.account,
    }
  );

  const events = await contract.getEvents.Initialized({
    pa: arg.pa,
    ra: arg.ra,
  });

  return {
    lv: events[0].args.lv,
    Id: events[0].args.id,
  };
}

export type IssueNewSwapAssetsArg = {
  moduleCore: Address;
  config: Address;
  ra: Address;
  pa: Address;
  expiry: number;
  factory: Address;
  rates?: bigint;
  repurhcaseFeePrecent?: bigint;
};

export async function mintRa(ra: Address, to: Address, amount: bigint) {
  const raContract = await hre.viem.getContractAt("DummyERCWithMetadata", ra);
  await raContract.write.mint([to, amount]);
}

export async function issueNewSwapAssets(arg: IssueNewSwapAssetsArg) {
  const { defaultSigner } = await getSigners();

  const rate = arg.rates ?? parseEther("1");
  // 10% by default
  const repurchaseFeePercent = arg.repurhcaseFeePrecent ?? parseEther("10");

  const contract = await hre.viem.getContractAt("ModuleCore", arg.moduleCore);
  const Id = await contract.read.getId([arg.pa, arg.ra]);

  const configContract = await hre.viem.getContractAt("CorkConfig", arg.config);
  await configContract.write.issueNewDs(
    [Id, BigInt(arg.expiry), rate, repurchaseFeePercent],
    {
      account: defaultSigner.account,
    }
  );

  const events = await contract.getEvents.Issued({
    Id,
    expiry: BigInt(arg.expiry),
  });

  return {
    ct: events[0].args.ct,
    ds: events[0].args.ds,
    dsId: events[0].args.dsId,
    Id,
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

export type CreateLvArg = {
  moduleCore: Address;
  ra: Address;
  pa: Address;
  factory: Address;
};

export async function createLv(arg: CreateLvArg) {
  const { defaultSigner } = await getSigners();
  const contract = await hre.viem.getContractAt("AssetFactory", arg.factory);

  await contract.write.deployLv([arg.ra, arg.pa, arg.moduleCore], {
    account: defaultSigner.account,
  });

  const events = await contract.getEvents.LvAssetDeployed({
    ra: arg.ra,
  });

  return await hre.viem.getContractAt("Asset", events[0].args.lv!);
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

export async function onlymoduleCoreWithFactory() {
  const factory = await deployAssetFactory();
  const config = await deployCorkConfig();
  const moduleCore = await deployModuleCore(
    factory.contract.address,
    config.contract.address
  );
  await factory.contract.write.initialize([moduleCore.contract.address]);

  return {
    factory,
    moduleCore,
    config,
  };
}

export async function ModuleCoreWithInitializedPsmLv() {
  const {
    factory,
    moduleCore: moduleCore,
    config,
  } = await onlymoduleCoreWithFactory();
  const { pa, ra } = await backedAssets();

  const fee = parseEther("10");
  // 0 for now cause we dont have any amm
  const depositThreshold = parseEther("0");

  const { Id, lv } = await initializeNewPsmLv({
    moduleCore: moduleCore.contract.address,
    config: config.contract.address,
    pa: pa.address,
    ra: ra.address,
    lvFee: fee,
    lvAmmWaDepositThreshold: depositThreshold,
    lvAmmCtDepositThreshold: depositThreshold,
  });

  return {
    factory,
    moduleCore,
    config,
    lv: await hre.viem.getContractAt("Asset", lv!),
    pa,
    ra,
    Id: Id!,
    lvFee: fee,
    lvAmmWaDepositThreshold: depositThreshold,
    lvAmmCtDepositThreshold: depositThreshold,
  };
}

export async function backedAssets() {
  return await deployBackedAssets();
}

// async function fixture
