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
  CETH                            :  0x5A517Bdd28E6c82fc88DD94B255B182788d12080
  bsETH                           :  0xB926f1279e58AF494976D324CC38866018CCa892
  lbETH                           :  0xCa15c974445d7C8A0aA14Bd5E6b3aFd5F22D7D17
  wamuETH                         :  0xE7Df8d2654183E4C809803850A56829131ae77f6
  mlETH                           :  0x4Bc92B2E2066906e0b4C1E1D9d30f985375D9268
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0xA16C75fbdB9719832B38b54D07176978c495825A
  Asset Factory                   :  0xEf8e5a6410Ad6d96E50A88557a30f015dd4a7dFC
  Cork Config                     :  0x90C95749f0018F0C790CB2e9a93a2cE34181AdDA
  Flashswap Router Implementation :  0xd8A5e28c17402aA7f6692Ed2FCfFD9BD654A62Ee
  Flashswap Router Proxy          :  0xD9850bFE4b85972904FEe5e38f6be9117Ce1f18f
  Univ2 Factory                   :  0xaF2e1Ad77fAcc108d5085D2f12418936880EeEeD
  Univ2 Router                    :  0x733732F1C66f1973b90ca443022Cef2B287EFCB6
  Module Core                     :  0x1647873c50Ec462039d4Eb4Fbd7bdFD8835a1133
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

```
