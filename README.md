# Depeg Swap V1

This repository contains core smart contracts of Depeg Swaps, for higher level specification and flows please see the design [documents](https://corkfi.notion.site/Smart-Contract-Flow-fc170aec36bc43579a7d0429c49e08ab) for now.

# Build
Install required dependencies :
```bash
yarn
```

To build & compile all contracts simply run :

```bash
yarn build
```

# Tests

To run test, use this command :

```bash
yarn test
```

# Deployments

- read `.env.example` variables descriptions
- copy the contents to your `.env` and fill it with your value
- run this command :

```bash
npx hardhat run scripts/deploy.ts --network <network>
```

in the first run you may see errors like :

```bash
IgnitionError: IGN403: You have sent transactions from 0x3e995c17172ea3e23505adfe5630df395a738e51 and they interfere with Hardhat Ignition. Please wait until they get 5 confirmations before running Hardhat Ignition again.
```

This is because we actualy don't use ignition when deploying uniswap v2 related contracts(e.g factory, router). Instead, we use ethers due to the fact that for some reason, deploying using ignition modules won't work with uniswap v2 contracts. To resolve this, simply run the command again. This usually takes 1-2 times, but don't worry, all of the previous deployments will be cached

```bash
npx hardhat run script/hardhat-scripts/deploy.ts --network <network>

forge script script/foundry-scripts/Deploy.s.sol:DeployScript --rpc-url https://1rpc.io/sepolia --broadcast -vvv --with-gas-price 25000000000
```

AFter that, you should see something like this on your terminal :

```bash
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  PRODUCTION                   : undefined
  Network                      : sepolia
  Chain Id                     : 11155111
  Deployer                     : 0xFFB6b6896D469798cE64136fd3129979411B5514
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH                            :  0x3BFE8e8821995737187c0Dfb4F26064679EB7C7F
  bsETH                           :  0xcDD25693eb938B3441585eBDB4D766751fd3cdAD
  lbETH                           :  0xA00B0cC70dC182972289a0625D3E1eFCE6Aac624
  wamuETH                         :  0x79A8b67B51be1a9d18Cf88b4e287B46c73316d89
  mlETH                           :  0x68eb9E1bB42feef616BE433b51440D007D86738e
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x87e7edDe42262Fa1B1D5E9812913A8E949905778
  Asset Factory                   :  0xC4A555D07d61a63cC169fdDE7CeC56eDb534d966
  Cork Config                     :  0x25F8d3dB6c0cfC8815972C6Faaea875d48d1b401
  Flashswap Router Implementation :  0x3cb645E348192E8eDB986376B0788C07D66Db625
  Flashswap Router Proxy          :  0x6F0FFC87FD1695DDBACf39fdCebD8632cc0B1043
  Univ2 Factory                   :  0x9bF06D55b1ba75b9F7819853958Cb292d700c18F
  Univ2 Router                    :  0x2eAc54667957a8a4312c92532df47eEBAE7bc36e
  Module Core                     :  0xa97e7b244B1C853b5981E2F74C133a68d9941F03
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xd301e625fAFF0C21e157f3b9154CFF44DD963728
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
