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
  CETH                            :  0x0cf81AA530c6064E369642270D15e5b65a584e18
  wamuETH                         :  0xa6D4a61BAefDee7b6041DfE7626C92AF0A4fb59f
  bsETH                           :  0x9d56764374b1350399B2de5E7192AB653e3fa5e6
  mlETH                           :  0x1A3A9257a951736B4a1b8b1bD99D11feC4C14E54
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  CUSD                            :  0xE5138a279C2238ECFB95186E71Bf0fE7131B7743
  svbUSD                          :  0x05eB28b50654Cf93ee5A004Dc4d5F8801d92D6ec
  fedUSD                          :  0xb8e31143A44c5b556c07341349d6b76757349957
  omgUSD                          :  0x4430B06b87a1fe0657b2ad814c46867dcAb753b4
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0xA4c0120B3fDD2999266F572e7694247c1C2285Ce
  Asset Factory                   :  0x2aC728D2489F4621ff8DB04945c5d1D62057fca6
  Cork Config                     :  0xafB704b12d1B04d1083547Df45B3061117d91195
  Flashswap Router Implementation :  0x803b68A0F24F4dd1eE773E63B89bD2395A4580b8
  Flashswap Router Proxy          :  0x2E7f058ACDAc65A0362b35Efe7F950D545DBCace
  ModuleCore Router Implementation:  0x0b92d711F6D4168786Db648dA2b00A9c85328DBF
  Pool Manager                    :  0x4C426Ba4078547b66108C789516DB3E488Df45E7
  Liquidity Token                 :  0x1d34Af5c89b438E7962Da9ded9dD694400e8dcD0
  Hook                            :  0x792140A59aD4800368Bbe7843D4ED9f534022a88
  Module Core                     :  0x191867e1650738276175D35a6c17114aaBA20975
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Liquidator                      :  0xB92BE5358555f1BeC91e80F170Af6886fA5FD364
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Univ2 Factory                   :  0xF62c03E08ada871A0bEb309762E260a7a6a880E6
  Univ2 Router                    :  0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Funder Contract                 :  0xdAD2E0651F88D5EA6725274153209Fe94DF8c829
  Reader Contract                 :  0xC4736Ba3D54df3725771d889b964114535d4bF2D
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
```
