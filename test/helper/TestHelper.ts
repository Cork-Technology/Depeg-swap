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
import UNIV2FACTORY from "./ext-abi/hardhat/uni-v2-factory.json";
import UNIV2ROUTER from "./ext-abi/hardhat/uni-v2-router.json";
import { ethers } from "ethers";
import { toUtf8Bytes } from "ethers/lib/utils";

const DEVISOR = BigInt(1e18);
export const DEFAULT_BASE_REDEMPTION_PERCENTAGE = parseEther("5");

export function calculatePercentage(
  number: bigint,
  percent: bigint = DEFAULT_BASE_REDEMPTION_PERCENTAGE
) {
  return (number * DEVISOR * percent) / parseEther("100") / DEVISOR;
}

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

export function toEthersBigNumer(v: bigint | string) {
  if (typeof v == "bigint") {
    return ethers.BigNumber.from(v);
  }

  if (typeof v == "string") {
    return ethers.BigNumber.from(parseEther(v));
  }
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

export function getSigners(
  signers: Awaited<ReturnType<typeof hre.viem.getWalletClients>>
) {
  const defaultSigner = signers.shift()!;
  const secondSigner = signers.shift()!;

  return {
    signers,
    defaultSigner,
    secondSigner,
  };
}

export async function deployAssetFactory() {
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);
  const assetFactorycontract = await hre.viem.deployContract(
    "AssetFactory",
    [],
    {
      client: {
        wallet: defaultSigner,
      },
    }
  );

  const initializeData = "0x8129fc1c";
  const assetFactoryProxy = await hre.viem.deployContract("ERC1967Proxy", [
    assetFactorycontract.address,
    initializeData,
  ]);
  const contract = await hre.viem.getContractAt(
    "AssetFactory",
    assetFactoryProxy.address
  );

  return {
    contract,
  };
}

export async function deployCorkConfig() {
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);
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

export async function deployFlashSwapRouter(
  mathHelper: Address,
  config: Address
) {
  const mathLib = await hre.viem.deployContract("SwapperMathLibrary");
  const routerContract = await hre.viem.deployContract("RouterState", [], {
    libraries: {
      SwapperMathLibrary: mathLib.address,
      MathHelper: mathHelper,
    },
  });

  // Step 3: Manually encode the initialization data (initialize(address))
  // 'initialize(address)' has the function selector 'initialize(address)' and takes a single 'address' argument
  const initializeData = "0xc4d66de8" + config.slice(2).padStart(64, "0");
  const routerProxy = await hre.viem.deployContract(
    "ERC1967Proxy",
    [routerContract.address, initializeData],
    {}
  );
  const contract = await hre.viem.getContractAt(
    "RouterState",
    routerProxy.address
  );

  return {
    contract,
  };
}

// will default use the first wallet client
export async function deployUniV2Factory(flashswap: Address) {
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);

  const hash = await defaultSigner.deployContract({
    abi: UNIV2FACTORY.abi,
    bytecode: `0x${UNIV2FACTORY.evm.bytecode.object}`,
    account: defaultSigner.account,
    args: [ethers.constants.AddressZero, flashswap],
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
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);

  const hash = await defaultSigner.deployContract({
    abi: UNIV2ROUTER.abi,
    bytecode: `0x${UNIV2ROUTER.evm.bytecode.object}`,
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
  config: Address,
) {
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);

  const mathLib = await hre.viem.deployContract("MathHelper");
  const psm = await hre.viem.deployContract("PsmLibrary", [], {
    libraries: {
      MathHelper: mathLib.address,
    },
  });

  const vault = await hre.viem.deployContract("VaultLibrary", [], {
    libraries: {
      MathHelper: mathLib.address,
    },
  });

  const dsFlashSwapRouter = await deployFlashSwapRouter(
    mathLib.address,
    config
  );
  const univ2Factory = await deployUniV2Factory(
    dsFlashSwapRouter.contract.address
  );
  const weth = await deployWeth();
  const univ2Router = await deployUniV2Router(
    weth.contract.address,
    univ2Factory,
    dsFlashSwapRouter.contract.address
  );

  const moduleCoreContract = await hre.viem.deployContract("ModuleCore", [], {
    client: {
      wallet: defaultSigner,
    },
    libraries: {
      VaultLibrary: vault.address,
      PsmLibrary: psm.address,
    },
  });

  const initializeData =
    "0x1459457a" +
    [
      swapAssetFactory,
      univ2Factory,
      dsFlashSwapRouter.contract.address,
      univ2Router,
      config,
    ]
      .map((address) => address.slice(2).padStart(64, "0"))
      .join(""); // Remove `0x` and pad each address to 32 bytes

  const moduleCoreProxy = await hre.viem.deployContract(
    "ERC1967Proxy",
    [moduleCoreContract.address, initializeData],
    {}
  );
  const contract = await hre.viem.getContractAt(
    "ModuleCore",
    moduleCoreProxy.address
  );

  await dsFlashSwapRouter.contract.write.setModuleCore([contract.address]);
  // await dsFlashSwapRouter.contract.write.transferOwnership([contract.address]);

  return {
    contract,
    univ2Factory,
    univ2Router,
    dsFlashSwapRouter,
    weth,
  };
}

export type InitializeNewPsmArg = {
  factory: Address;
  moduleCore: Address;
  config: Address;
  pa: Address;
  ra: Address;
  lvFee: bigint;
  initialDsPrice?: bigint;
  rates: bigint;
};

export async function initializeNewPsmLv(arg: InitializeNewPsmArg) {
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);
  const factory = await hre.viem.getContractAt("AssetFactory", arg.factory);
  const contract = await hre.viem.getContractAt("ModuleCore", arg.moduleCore);
  const configContract = await hre.viem.getContractAt("CorkConfig", arg.config);
  const dsPrice = arg.initialDsPrice ?? parseEther("0.1");

  await configContract.write.setModuleCore([arg.moduleCore], {
    account: defaultSigner.account,
  });

  await configContract.write.initializeModuleCore([
    arg.pa,
    arg.ra,
    arg.lvFee,
    dsPrice,
    arg.rates
  ]);
  const events = await contract.getEvents.InitializedModuleCore({
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
  const raContract = await hre.viem.getContractAt("DummyERCWithPermit", ra);
  await raContract.write.mint([to, amount]);
}

export async function issueNewSwapAssets(arg: IssueNewSwapAssetsArg) {
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);

  const rate = arg.rates ?? parseEther("1");
  // 5% by default
  const repurchaseFeePercent = arg.repurhcaseFeePrecent ?? parseEther("5");

  const contract = await hre.viem.getContractAt("ModuleCore", arg.moduleCore);
  const Id = await contract.read.getId([arg.pa, arg.ra]);

  const configContract = await hre.viem.getContractAt("CorkConfig", arg.config);
  await configContract.write.issueNewDs(
    [
      Id,
      BigInt(arg.expiry),
      rate,
      repurchaseFeePercent,
      parseEther("1"),
      10n,
      BigInt(expiry(1000000)),
    ],
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
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);

  const pa = await hre.viem.deployContract(
    "DummyERCWithPermit",
    [DUMMY_PA_NAME, DUMMY_PA_TOKEN],
    {
      client: {
        wallet: defaultSigner,
      },
    }
  );

  const ra = await hre.viem.deployContract(
    "DummyERCWithPermit",
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
  const signers = await hre.viem.getWalletClients();
  const { defaultSigner } = getSigners(signers);
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
  functionName?: string;
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

      // Calculate the function hash using the provided functionName
  const functionHash = keccak256(toUtf8Bytes(arg.functionName));

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
      {
        name: "functionHash",
        type: "bytes32",
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
    functionHash: functionHash, // Add functionHash to values
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

export async function permitForRA(arg: PermitArg) {
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

export async function onlymoduleCoreWithFactory(basePsmRedemptionFee: bigint) {
  const factory = await deployAssetFactory();
  const config = await deployCorkConfig();
  const { contract, dsFlashSwapRouter, univ2Factory, univ2Router, weth } =
    await deployModuleCore(
      factory.contract.address,
      config.contract.address,
    );
  const moduleCore = contract;
  await factory.contract.write.transferOwnership([moduleCore.address]);

  return {
    factory,
    moduleCore,
    config,
    dsFlashSwapRouter,
    univ2Factory,
    univ2Router,
    weth,
  };
}

export async function ModuleCoreWithInitializedPsmLv(
  basePsmRedemptionFee: bigint = DEFAULT_BASE_REDEMPTION_PERCENTAGE
) {
  const {
    factory,
    moduleCore: moduleCore,
    config,
    dsFlashSwapRouter,
    univ2Factory,
    univ2Router,
    weth,
  } = await onlymoduleCoreWithFactory(basePsmRedemptionFee);
  const { pa, ra } = await backedAssets();

  const fee = parseEther("5");

  const { Id, lv } = await initializeNewPsmLv({
    factory: factory.contract.address,
    moduleCore: moduleCore.address,
    config: config.contract.address,
    pa: pa.address,
    ra: ra.address,
    lvFee: fee,
    rates: basePsmRedemptionFee,
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
    dsFlashSwapRouter,
    univ2Factory,
    univ2Router,
    weth,
  };
}

export async function backedAssets() {
  return await deployBackedAssets();
}

// async function fixture
