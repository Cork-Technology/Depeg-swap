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
  CETH                            :  0x6D9DD9fB3a1bd4fB0310DD5CE871AB1A75aa0197
  wamuETH                         :  0x442b2A6b0b7f0728fE72E381f9eC65cbE92EF92d
  bsETH                           :  0x52480170Cf53f76bABACE04b84d3CbBd8cCfcAf2
  mlETH                           :  0xBaFc88AfcF2193f326711144578B7874F1Ef1F63
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0x647DE4ac37023E993c5b6495857a43E0566e9C7d
  svbUSD                          :  0x34F48991F54181456462349137928133d13a142f
  fedUSD                          :  0x2ca2F3872033BcA2C9BFb8698699793aED76FF94
  omgUSD                          :  0xe94E4045B69829fCf0FC9546006942130c6c9836
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0xbD4b12b35b680bD396051414f55A78f7ae0533cc
  Asset Factory                   :  0x37458dB9018cbaD85Bd5711D630b0a0ccA39e8f8
  Cork Config                     :  0xf8fa7A887b3a6A8d18F1DC314102A5AD72bDd864
  Flashswap Router Implementation :  0x0d8c7CC11E0f47D02c8C47a673B79e8836191EC6
  Flashswap Router Proxy          :  0x20dB2489fd2E58D969Cf3990c5324f3215D7dA8f
  ModuleCore Router Implementation:  0x2A297fb59544271068a31E3cebe9b39E3709D1d2
  Pool Manager                    :  0x2D5Ed002fF3FcaFCeEbFa1304CBda745AB08AaC0
  Liquidity Token                 :  0x6530D6d4C9B852fe30bbD6188149030619284bE7
  Hook                            :  0x8eDe9184318a079385D7C6E2B4432Db1ecA96a88
  Module Core                     :  0x62525738d67cb833B65e0783293737F0c1a2636C
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
