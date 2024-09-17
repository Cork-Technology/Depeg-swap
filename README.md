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
  CETH                            :  0x097d0Ffc93EC3367d08D6b4F1805cFe1EEAeCD1A
  bsETH                           :  0xDCb731a860ddBBde640361e1542DD1c11BE006A1
  lbETH                           :  0xC63B2F21FE51f7F608e8801993747B7f6D3347B5
  wamuETH                         :  0x40a74feb837A0BB201C9BffE07aD2eb0095166c1
  mlETH                           :  0x3f934BEd20fA90ac88c1b282C19E1547eAC74332
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0xd0060DF5Dc58aFbB55fD141879c1b199254B5f4f
  Asset Factory                   :  0x5FC922BA6AaeB1aF51639a198ECd3EF00f948fFD
  Cork Config                     :  0x9Aebdf8F542D4d07A1376D9d17Df08c5eA5573e2
  Flashswap Router Implementation :  0x5cA0aa7E83F3DEe02305e53ceEbc116DDDe93Fa6
  Flashswap Router Proxy          :  0x366E259c075B410241FE309BF7B066256b431A93
  Univ2 Factory                   :  0xeC2a304Ff0a33C38A1ae40472bD222CBF344251B
  Univ2 Router                    :  0xe7DD6aB5025fEd9be9937f4116230607C1c1f7E2
  ModuleCore Router Implementation :  0x85DD734155586AC84A92DE4219eB797C3Ff11d30
  Module Core                     :  0xf774E510ce115b2C1c3A22A9743Eb9b950b8F7c9
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
