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
  CETH                            :  0xD4B903723EbAf1Bf0a2D8373fd5764e050114Dcd
  wamuETH                         :  0x212542457f2F50Ab04e74187cE46b79A8B330567
  bsETH                           :  0x71710AcACeD2b5Fb608a1371137CC1becFf391E0
  mlETH                           :  0xc63b0e46FDA3be5c14719257A3EC235499Ca4D33
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0x8cdd2A328F36601A559c321F0eA224Cc55d9EBAa
  svbUSD                          :  0x80bA1d3DF59c62f3C469477C625F4F1D9a1532E6
  fedUSD                          :  0x618134155a3aB48003EC137FF1984f79BaB20028
  omgUSD                          :  0xD8CEF48A9dc21FFe2ef09A7BD247e28e11b5B754
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x57B75AE79fb25113e3b3Aac576fE2121B44393c5
  Asset Factory                   :  0x938A8Be7e60A666d807a7948304b82cFdEe67Af8
  Cork Config                     :  0xcc79b14DA0891a00a6d3216b49d77815d1fEdC36
  Flashswap Router Implementation :  0x6DDcfd062B05C3CE78100caE9E2a856ddf01b2AF
  Flashswap Router Proxy          :  0x7ff313778Ca50e1cB5BD8a3B1408D931F14FEce4
  ModuleCore Router Implementation:  0xBBAB023Aeb8b965689dd68fa6F2826F5078c13db
  Pool Manager                    :  0x21E0D6713a5BE74BA3C3dA29a8Cdb2dD2854406f
  Liquidity Token                 :  0x1359c5485dB6E9b4B9795b62F9c8528077dD0bea
  Hook                            :  0x47e14768fFd0E5514cEe87E0e3dF23F7C5bfAA88
  Module Core                     :  0x0e5212A25DDbf4CBEa390199b62C249aBf3637fF
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0xbE312f50A41468DA8BB456FAdFddf4e096058510
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  HedgeUnit Factory               :  0x4F80d6c1d4Dda7f50b6E5aC32E53dd0f9B31f2ec
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  HU wamuETH                      :  0xC1B7C5ae32cE51aD0dcB2c4148106E6771Fd9C6F
  HU bsETH                        :  0xF24F322665837D7b618c49F6Ba0bb6ADC6f0E6ee
  HU mlETH                        :  0xf65f04F5dA7CD20056132D9e0f617d7d12d64A0C
  HU fedUSD                       :  0xc9d6fC8e44C9860E969e6DC1F2294AB5bD62891A
  HU svbUSD                       :  0x997D6216E30061896569Ec7FB8176908Eb8a00Cd
  HU omgUSD                       :  0xbF1F8661BdBB2b7b9073D3369A017D52B584eaAd
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
