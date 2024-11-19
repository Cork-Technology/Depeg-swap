# Depeg Swap V1

This repository contains core smart contracts of Depeg Swaps, for higher level specification and flows please see the design [documents](https://corkfi.notion.site/Smart-Contract-Flow-fc170aec36bc43579a7d0429c49e08ab) for now.

# Build

Install required dependencies :(related to hardhat)

```bash
yarn
```

Install required dependencies :(related to foundry)

```bash
forge install Openzeppelin/openzeppelin-contracts@v5.0.2
forge install Openzeppelin/openzeppelin-contracts-upgradeable@v5.0.2
forge install Cork-Technology/v2-core@v1.0.2
forge install Cork-Technology/v2-periphery@v1.0.1                   
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
  Deployer                     : 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH                            :  0x93D16d90490d812ca6fBFD29E8eF3B31495d257D
  bsETH                           :  0xb194fc7C6ab86dCF5D96CF8525576245d0459ea9
  lbETH                           :  0xF24177162B1604e56EB338dd9775d75CC79DaC2B
  wamuETH                         :  0x38B61B429a3526cC6C446400DbfcA4c1ae61F11B
  mlETH                           :  0xCDc1133148121F43bE5F1CfB3a6426BbC01a9AF6
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x92D8b534237C5Be34753b975D53a14b494b96Ef4
  Asset Factory                   :  0xbdfc069558B9d87Df40f9A4876Fa7c52f6492788
  Cork Config                     :  0x8c996E7f76fB033cDb83CE1de7c3A134e17Cc227
  Flashswap Router Implementation :  0x3687694873bA2A746609fbd3B33CDb69b30BA602
  Flashswap Router Proxy          :  0x6629e017455CB886669e725AF1BC826b65cB6f24
  Univ2 Factory                   :  0x8fD48F4ec9cB04540134c02f4dAa5f68585c3936
  Univ2 Router                    :  0x363E8886E8FF30b6f6770712Cf4e758e2Bf3E353
  ModuleCore Router Implementation:  0xb0926d56e9C9A72A1412B54d5555782cCD56124F
  ModuleCore Router Proxy         :  0xe56565c208d0a8Ca28FB632aD7F6518f273B8B9f
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
