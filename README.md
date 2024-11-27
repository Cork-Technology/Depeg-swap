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
forge install Uniswap/v4-periphery
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

forge script script/foundry-scripts/DeployTokens.s.sol:DeployTokensScript

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
  CETH                            :  0x11649B3aEc3D4Cd35D0727D786c234329B756fd9
  wamuETH                         :  0x81EcEa063eB1E477365bd6c0AE7E1d1f3d84442E
  bsETH                           :  0x2019e2E0D0DE78b65ce698056EAE468192b40daC
  mlETH                           :  0xD1813fD95E557d273E8009db91C6BC412F56eE56
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0x4c82BdeDD41bf0284fd6BCa1b6A317fEF6A6d237
  svbUSD                          :  0xeD273d746bC1CefA9467ea5e81e9cd22eaC27397
  fedUSD                          :  0xEBdc16512a8c79c39EB27cc27e387039AF573f82
  omgUSD                          :  0x42B025047A12c403803805195230C257D2170Bb1
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0xd048242Be976cd502b776fd6B2929778151f67dD
  Asset Factory                   :  0x63D1F2Aa11bA5d576bFACb419BB918F2E5f000F0
  Cork Config                     :  0xCA98b865821850dea56ab65F3f6C90E78D550015
  Flashswap Router Implementation :  0x939ed4Edf62277983111d0C116CC27191404E596
  Flashswap Router Proxy          :  0x96EE05bA5F2F2D3b4a44f174e5Df3bba1B9C0D17
  ModuleCore Router Implementation:  0x45833844EecDE4Ce59402B638c0B2CfD27E45C72
  Pool Manager                    :  0xFA681f1Acc6BB8dF53BdA809bE517628bDDdbD5a
  Liquidity Token                 :  0x34C759A661EC463a93e5ba2d902C4134c53c9765
  Hook                            :  0x77f003DC035F5215A9aEEF350e4e44236dB5aa88
  Module Core                     :  0x3390573A8Cd1aB9CFaE5e1720e4e7867Ed074a38
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0x15c3f629b4443EaE0225E85E91D1e0a7E587a641
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
