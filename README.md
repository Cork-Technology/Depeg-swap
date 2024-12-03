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
  Deployer                     : 0xBa66992bE4816Cc3877dA86fA982A93a6948dde9
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CETH                            :  0xc3E528E9675920dA0b03556719402D05d6b9A475
  wamuETH                         :  0x6915f849a6cdE397cb455ca18C15Cb2844522170
  bsETH                           :  0x51ca8a8BdB714ED0F4b565394675d864a41c65a7
  mlETH                           :  0xf5F20dfC98aE76d2905A82508cf609573B4D2a83
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0x26E69813240faf8f3e06c7B907cff78b99a28C97
  svbUSD                          :  0x03B03D8dc8d536C068eCf61b444c410aF2D8Ffee
  fedUSD                          :  0x7976B317bEB15d538c3d86fBeD661Dc511030998
  omgUSD                          :  0x0A19aF443f5677602D139344100F5Bc25A7Ef9A5
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x78c21D1dC07E364e972993219223CE5dEbaEfbba
  Asset Factory                   :  0xcf17533a7424444c02C3f3E517B28Db039Abd0FF
  Cork Config                     :  0x7D5c1F170329ce40169Bc1a833EB2D5760aA57d3
  Flashswap Router Implementation :  0xa85395c50092A8Fb9638bcBFB15098525c678D02
  Flashswap Router Proxy          :  0xDD08E978C78F48811B6DE871E14F017DD8feCe39
  ModuleCore Router Implementation:  0xed78ee3715D7CB74D17277B65cEFB2c19610A10F
  Pool Manager                    :  0xD311Df5688385BC0f8D8C3c4512ea7C9e354Bb68
  Liquidity Token                 :  0x49B1C03B0cA9D39e0B52c5c8Ca28F4807959e76c
  Hook                            :  0x77714c73431b785DC2fC9A318f57f92a6CD3AA88
  Module Core                     :  0x750a8Ea50082aF3dB2dd7c500AEDE2676363e54e
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0x8fBD6580B35816aC091bA6fbf2aDF2884581C606
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
