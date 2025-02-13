# Depeg Swap V1

This repository contains core smart contracts of Depeg Swaps.
# Build

Install required dependencies 

```bash
forge install
```
To build & compile all contracts for testing purposes run :

```bash
forge build
```

### Deployment Build
For production you need to use the optimized build with IR compilation turned on by setting the `FOUNDRY_PROFILE` environment variable to `optimized`:
```bash
FOUNDRY_PROFILE=optimized forge build
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
forge test
```

To run Formal verification proofs, use below commands :

```bash
export FOUNDRY_PROFILE=kontrol-properties
kontrol build
kontrol prove
```

  Mainnet Addresses
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Deployer                        :  0x777777727073E72Fbb3c81f9A8B88Cc49fEAe2F5
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Asset Factory Implementation    :  0x1Dc70bD6b9b939CdA32ab947459c093BBa29E3A7
  Asset Factory                   :  0x96E0121D1cb39a46877aaE11DB85bc661f88D5fA
  Cork Config                     :  0xF0DA8927Df8D759d5BA6d3d714B1452135D99cFC
  Flashswap Router Implementation :  0x65f2A587912aE1e92fAB28412D2dbaA41242EA71
  Flashswap Router Proxy          :  0x55B90B37416DC0Bd936045A8110d1aF3B6Bf0fc3
  ModuleCore Router Implementation:  0xFE3B9DCD2DfDba7386fBA9fFf62359Bc3D49B05F
  Pool Manager                    :  0x9ff1CD7248f8078188995bAB0240311f68cB4DF6
  Liquidity Token                 :  0xcAaCF4766B8d112ec1286b73765A99a7fe94b4A2
  Hook                            :  0x0f956f42d92e478e9d61b5432c5080c09134AA88
  Module Core                     :  0x0e1968D9f29E99f14F9023021219eCedD67EB712
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  Withdrawal                      :  0xb9Abffdd175B0F58c340E85158F8823825269008
  Exchange Rate Provider          :  0x7b285955DdcbAa597155968f9c4e901bb4c99263
  -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
