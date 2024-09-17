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
  CETH                            :  0xe9D04fa86c4Ef0B1f542aE98635c3F92762B0572
  bsETH                           :  0xC7b6F5Bec58ad96855cE9307ac3022e797A767B2
  lbETH                           :  0xa741B0Cb404D935e3b684cFE4164401d3fF643f9
  wamuETH                         :  0x694F8a713283C2729a248022b12f7bE0830691c3
  mlETH                           :  0x683E9F579bfeE52715a9604a7338B1748b93b53C
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x7A6B0309A6b27F1663adda1e768a046558e290F6
  Asset Factory                   :  0x52b29807912FA6B92d63B84df4dd206207E627FC
  Cork Config                     :  0x7b7721e009CFF8E500939ed2E6b3070A9c51f159
  Flashswap Router Implementation :  0x36D0Fc79d5c67e71D340B5075012D286a0484583
  Flashswap Router Proxy          :  0xF0200c587f728d10bB5665d93dDF0f3CeeDf4e9e
  Univ2 Factory                   :  0x47C81Cc1cb625107657Ec7c5Ae8827A1F7840174
  Univ2 Router                    :  0xCB7BD2282f3afAab270A8Eed4187524CbeEdED56
  ModuleCore Router Implementation :  0x2c8FAd4472C8100aafA0A4493276607719a0A91C
  Module Core                     :  0xE79966474580c517959C3023acF633c990653d21
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Transferred ownerships to Modulecore
  Modulecore configured in Config contract
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  New DS issued
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  LV Deposited
  Liquidity Added to AMM
  New DS issued
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  LV Deposited
  Liquidity Added to AMM
  New DS issued
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xd301e625fAFF0C21e157f3b9154CFF44DD963728
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
