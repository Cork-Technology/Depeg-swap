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
  CETH                            :  0x042Ab9F32E0f403C2094b7e50a2eb947215f6443
  bsETH                           :  0xA65334d8cBec2804665380313a614Bd320d2B57F
  lbETH                           :  0x1151519A2473CfA6186E74e37cf1F35AEC957Fe9
  wamuETH                         :  0x0287496b4d221F671b040829A257e9d24e87129f
  mlETH                           :  0x76798E8e2A8e57075ae8b54057163F6E7e583cB4
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0xc77426230D5c8ceBeE4D129b25a4595ED9C79C7b
  Asset Factory                   :  0xED909448Dd107a8854A7E3f81126357145Dc54b9
  Cork Config                     :  0x8D890e7c1CC58Ae039E899A30a5345ac90B8704F
  Flashswap Router Implementation :  0x188c0D656eAEe1a854092AdE9d88D2CEEb04bdC5
  Flashswap Router Proxy          :  0x8AA0e75898BCd2B9979e825Aecf2a349E82452EC
  Univ2 Factory                   :  0x995914a885927b35F74bC2d68a11Bf24941EB40b
  Univ2 Router                    :  0x8c44A71d4f159d9cB495eF77Ab911da15d83DFe0
  ModuleCore Router Implementation :  0x5A64B6Ab6BF994871a1f662162bFD03866876fc9
  Module Core                     :  0x08d8FcCb67B63fC6d89B0fF473FE94818aF40C99
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
