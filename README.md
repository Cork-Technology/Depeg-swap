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
  TC Contracts
  CETH deployed to                : 0x8135505f4C49e4Bd882b7fB7a33051C49feBB1d9
  bsETH deployed to               : 0x47Ac327afFAf064Da7a42175D02cF4435E0d4088
  lbETH deployed to               : 0x36645b1356c3a57A8ad401d274c5487Bc4A586B6
  wamuETH deployed to             : 0x64BAdb1F23a409574441C10C2e0e9385E78bAD0F
  mlETH deployed to               : 0x5FeB996d05633571C0d9A3E12A65B887a829f60b
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH USED                       :  0x8135505f4C49e4Bd882b7fB7a33051C49feBB1d9
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x8c65cA47c5724f3E91f94917BE0Fb6aC21620114
  Asset Factory                   :  0x8Cb83D51a1a4e786069013e5F57020ff35103c67
  Cork Config                     :  0xdaBe7aDC50420Df3FDf9D3E2c19B86d19FAC6b55
  Flashswap Router Implementation :  0xc0CAaA5d2131457Ad59Da64e032570E92181B674
  Flashswap Router Proxy          :  0x34AeB26069858993385774dcF6A9AA18C47AAc72
  Univ2 Factory                   :  0xE14344fb9488C55A27da37cd9351B97A577Ed363
  Univ2 Router                    :  0x334B2C016372cdBbB37C5AD3a09A8e055ab6d3f5
  Module Core                     :  0xf6fa5512A057e34707361155c4ae9ea94e759b8E
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
