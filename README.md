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

forge script script/foundry-scripts/Deploy.s.sol:DeployScript --rpc-url https://1rpc.io/sepolia --broadcast -vvv --with-gas-price 25000000000 --verify
```

AFter that, you should see something like this on your terminal :

```bash
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  PRODUCTION                   : undefined
  Network                      : sepolia
  Chain Id                     : 11155111
  Deployer                     : 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH                            :  0x34505854505A4a4e898569564Fb91e17614e1969
  wamuETH                         :  0xd9682A7CE1C48f1de323E9b27A5D0ff0bAA24254
  bsETH                           :  0x0BAbf92b3e4fd64C26e1F6A05B59a7e0e0708378
  mlETH                           :  0x98524CaB765Cb0De83F71871c56dc67C202e166d
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0xEEeA08E6F6F5abC28c821Ffe2035326C6Bfd2017
  svbUSD                          :  0x7AE4c173d473218b59bF8A1479BFC706F28C635b
  fedUSD                          :  0xd8d134BEc26f7ebdAdC2508a403bf04bBC33fc7b
  omgUSD                          :  0x182733031965686043d5196207BeEE1dadEde818
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x774A52F5fB55eF70EE7b8fd519d204e26C2c6d51
  Asset Factory                   :  0x4AF771825Bf2c16A4B1A4725cc1D2799Ae1Ec244
  Cork Config                     :  0xa864464d74bdF23Dda5660c5e9b053357cBDE05c
  Flashswap Router Implementation :  0x6984b29Ec03220aB8ADd78A0Cd07562EBD066F49
  Flashswap Router Proxy          :  0xA4Ad536e6AE5D8B26b8AD079046dff60bAC9abad
  ModuleCore Router Implementation:  0x764a9A177a3B9F96e107c0Fb19C410F6851282eD
  Pool Manager                    :  0x79F9423FcB8A20E8928b2Ae8a4b83DCC353da087
  Liquidity Token                 :  0xB52987c3B140B8158BA2079DFD8865EA1e08Ec7A
  Hook                            :  0x9Fa49531cb18AAD419e05cAE866943E3f70Faa88
  Module Core                     :  0x8445a4caD9F5a991E668427dC96A0a6b80ca629b
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
