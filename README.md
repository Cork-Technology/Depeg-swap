# Depeg Swap V1
This repository contains core smart contracts of Depeg Swaps, for higher level specification and flows please see the design [documents](https://corkfi.notion.site/Smart-Contract-Flow-fc170aec36bc43579a7d0429c49e08ab) for now.

# Deployments
- read `.env.example` variables and what it does
- copy the contents, to your `.env` and fill it with your value
- run this command :
```bash
npx hardhat run scripts/deploy.ts --network <network>
```