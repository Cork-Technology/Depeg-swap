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
  Asset Factory Implementation    :  0x60360DF3de6c4bD6F5Fd2e7ba592303485fA9A9B
  Asset Factory                   :  0xf000cdA13733437Dfb12FeAE0A13d4763E990DB4
  Cork Config                     :  0x52741B3B3eF35595a4556060f6684a58460b275d
  Flashswap Router Implementation :  0x7633c1cb10a154096a7Ed3bf314822674D99A235
  Flashswap Router Proxy          :  0xAbc045f9BA3Ef72eD85A775F5d21356068AB4C10
  ModuleCore Router Implementation:  0x856df8aA608CCE52FF980BA382771d6Dc9AdeB7b
  Pool Manager                    :  0xDe8e90c3fea6e6A26F925f9b4c1C4e7084B6a676
  Liquidity Token                 :  0xC64AFb900B33EeCa2CE59A4d09fd2bF6b6971444
  Hook                            :  0x1Db7052Fbe1458FC507F2054090DAAb10c3bEa88
  Module Core                     :  0x2A97d50f625974A708eDbF6cF7ABA3fd9c08554F
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0x6cFc16600d1db1Ae34353e881B3AD79C346EaBea
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Reader Contract                 :  0x9c706773f25213B1a08f0D33E96b39D019b1DC66
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```