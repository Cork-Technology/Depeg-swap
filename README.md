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