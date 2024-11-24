# Depeg Swap V1

This repository contains core smart contracts of Depeg Swaps, for higher level specification and flows please see the design [documents](https://corkfi.notion.site/Smart-Contract-Flow-fc170aec36bc43579a7d0429c49e08ab) for now.

# Build

Install required dependencies :(related to hardhat)

```bash
yarn
```

Install required dependencies :(related to foundry)

```bash
forge install Openzeppelin/openzeppelin-contracts@v5.1.0
forge install Openzeppelin/openzeppelin-contracts-upgradeable@v5.1.0
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

// For deploying HedgeUnits separately
forge script script/foundry-scripts/DeployHedgeUnits.s.sol:DeployHedgeUnitsScript --rpc-url https://1rpc.io/sepolia --broadcast -vvv

```

AFter that, you should see something like this on your terminal :

```bash
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  PRODUCTION                   : undefined
  Network                      : sepolia
  Chain Id                     : 11155111
  Deployer                     : 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH                            :  0xa1c0010fc3006F9596C0D88558200caa53f74f21
  wamuETH                         :  0x62488d9A025AC5EB7694eeb03BDA1F19b3b14b46
  bsETH                           :  0x01CE7D0A18DCc77E22363Cb8e003f23f9De5a7fA
  mlETH                           :  0x7078462DaB16849E12Ba5bCf4C5075088b0C93Dc
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0x2884B1a347AbBff7396565A4f8C2dA722642e932
  svbUSD                          :  0x3e63b127287112D4A65CB09d348967c31b0DaB4c
  fedUSD                          :  0x33A4C083aa34846D300954E17Ae72b675Fc7aC65
  omgUSD                          :  0x3ccb5028dA93f5B226604f22Dd05d7b26eCfddf8
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x0E660c060c73902ba54422A22580cC4a244d8943
  Asset Factory                   :  0xBE663Ba82eBEb54bc4a3130069bE48771E2804C6
  Cork Config                     :  0x0B2BaD357477624b4D8f59a706312806Df5B7f75
  Flashswap Router Implementation :  0xea8AA1b8bE6C1Fc30e5Be038530C07c18d05Ad63
  Flashswap Router Proxy          :  0x2F02D8202E201f1DC0a3AE286c266635bB3cF018
  ModuleCore Router Implementation:  0x085f40cc08d4912E23b6F948A19c13E0CEC652CB
  Pool Manager                    :  0xf8b38d5c78760b99436243f8D764B2bFd72471D5
  Liquidity Token                 :  0xe3457C4D2Dc7e9E092EF00AE4A30dE82416BC077
  Hook                            :  0xB358a02356191350dC79E89cA0E33fF1006dEa88
  Module Core                     :  0xF0AE754660b418C99e4AbC3d4b1C96717CE7E4Fa
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0xF03c0d3c86424319613f6304D3ef1B741892f1c2
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  HedgeUnit Factory               :  0x354E95fBe8fC52bC449e2F4055eC00a790FcE823
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  HU wamuETH                      :  0x66F630F948Dc011E9689629d3BBA27718C6470D3
  HU bsETH                        :  0x10B32Dfbdd5fc6A5f6f7Ec2C53Ee53bA9cf4C5E6
  HU mlETH                        :  0x0E5F5FB9DD212815c8aF87f98B3378e8E6138dB2
  HU fedUSD                       :  0xE75CBBC83057928541a649AA25a6Cca8C64ea89E
  HU svbUSD                       :  0xfD1916E0C43785D693259Db87f92AC85e2bd78B6
  HU omgUSD                       :  0x492Cf38030A1c9D9Ee359F8628b1281722C0B184
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
