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
forge install Uniswap/v4-periphery
forge install Uniswap/v2-core@v1.0.1
forge install Uniswap/v2-periphery          
```

To build & compile all contracts simply run :

```bash
yarn build
```

# Setup Kontrol

To install kontrol use below commands : 

```bash 
bash <(curl https://kframework.org/install): install kup package manager.
kup install kontrol: install Kontrol.
kup list kontrol: list available Kontrol versions.
```

# Tests

To run test, use this command :

```bash
yarn test
```

To run Formal verification proofs, use below commands :

```bash
export FOUNDRY_PROFILE=kontrol-properties
kontrol build
kontrol prove
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
  Deployer                     : 0x036febB27d1da9BFF69600De3C9E5b6cd6A7d275
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH                            :  0x0000000237805496906796B1e767640a804576DF
  wamuETH                         :  0x22222228802B45325E0b8D0152C633449Ab06913
  bsETH                           :  0x33333335a697843FDd47D599680Ccb91837F59aF
  mlETH                           :  0x44444447386435500C5a06B167269f42FA4ae8d4
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0x1111111A3Ae9c9b133Ea86BdDa837E7E796450EA
  svbUSD                          :  0x5555555eBBf30a4b084078319Da2348fD7B9e470
  fedUSD                          :  0x666666685C211074C1b0cFed7e43E1e7D8749E43
  omgUSD                          :  0x7777777707136263F82775e7ED0Fc99Bbe6f5eB0
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x09bDC1d05CC708C8fB9fB3558046F4357EF98C23
  Asset Factory                   :  0x0e2da77bc7033a0D64992965a2262b7B9F3AbB07
  Cork Config                     :  0x190305d34e061F7739CbfaD9fC8e5Ece94C86467
  Flashswap Router Implementation :  0xF0eBa41b2E6deB47faECF8eD5d9d79A94A6E7312
  Flashswap Router Proxy          :  0x8547ac5A696bEB301D5239CdE9F3894B106476C9
  ModuleCore Router Implementation:  0x4932A32D731f5C4D37864f6655dEE26777182E79
  Pool Manager                    :  0x229433FC92588C5D164408939e4c460dC845372e
  Liquidity Token                 :  0xcCCA584A5ca7B82f10ad54b53e8d860Fb8c06889
  Hook                            :  0xf190c07670Db093962814393daCbF833CE02ea88
  Module Core                     :  0xF6a5b7319DfBc84EB94872478be98462aA9Aab99
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0x9700a0ca88BC835E992d819e59029965DBBfb1d6
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Reader Contract                 :  0x9c706773f25213B1a08f0D33E96b39D019b1DC66
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
