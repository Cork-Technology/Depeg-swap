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
npx hardhat run scripts/deploy.ts --network <network>
```

AFter that, you should see something like this on your terminal :

```bash
PRODUCTION                   : undefined
Network                      : sepolia
Chain Id                     : 11155111
Deployer                     : 0x3e995c17172ea3e23505adfe5630df395a738e51

AssetFactory deployed to     : 0xD5A39C05d6f5bffD7501287f975cE53c483FDA4C
CorkConfig deployed to       : 0x6B0636aaa7dB7D8bD05fFE147AF8CD295b2677c4
FlashSwapRouter deployed to  : 0x071a4F363AAC0948BA92bb1af698Bf09B89E8Fc6
UniV2Factory deployed to     : 0xc309a6A25B96D6aC843148ABF8100054c8644c38
UniV2Router deployed to      : 0x7f4e645054966556983B21a5Fe5eE6A17C21171a
ModuleCore deployed to       : 0xB2643D4b7Ee4aeb9f03CD0C18B971A141eC07f37
```
