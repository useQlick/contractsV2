# 🎉 Qlick Prediction Market - Deployment Successful!

**Network**: Base Sepolia (Chain ID: 84532)  
**Deployer**: `0x89fEdB2167199Fd069122e5351A1C779F91B8`  
**Date**: October 25, 2025

---

## 📋 Deployed Contract Addresses

### Core Contracts

| Contract | Address | Explorer |
|----------|---------|----------|
| **Market** | `0xa4Fc3e9739a2d991fDC4565607FEAb8A4ca1DDd8` | [View on BaseScan](https://sepolia.basescan.org/address/0xa4Fc3e9739a2d991fDC4565607FEAb8A4ca1DDd8) |
| **QUSD** | `0x2c6E9a46db09a9bB8756375B1a98161182a6DeCe` | [View on BaseScan](https://sepolia.basescan.org/address/0x2c6E9a46db09a9bB8756375B1a98161182a6DeCe) |
| **TokenFactory** | `0x70894B11caB80ADa3df2DAb918990C3Ec3F1180F` | [View on BaseScan](https://sepolia.basescan.org/address/0x70894B11caB80ADa3df2DAb918990C3Ec3F1180F) |
| **Resolver** | `0xfc6669763949938f76a47003b2f0C7a5f4587Cf0` | [View on BaseScan](https://sepolia.basescan.org/address/0xfc6669763949938f76a47003b2f0C7a5f4587Cf0) |
| **MarketView** | `0x54e985AA34F6C95cF3Cc0fbe15FAA16A4eb24174` | [View on BaseScan](https://sepolia.basescan.org/address/0x54e985AA34F6C95cF3Cc0fbe15FAA16A4eb24174) |

### Uniswap v4 (Pre-deployed on Base Sepolia)

| Contract | Address |
|----------|---------|
| **PoolManager** | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| **PositionManager** | `0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80` |
| **Universal Router** | `0x492e6456d9528771018deb9e87ef7750ef184104` |
| **StateView** | `0x571291b572ed32ce6751a2cb2486ebee8defb9b4` |
| **Quoter** | `0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba` |
| **Permit2** | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

---

## ✅ Configuration Status

- [x] All 6 contracts deployed successfully
- [x] QUSD minter set to Market contract
- [x] Permissions configured correctly
- [x] Deployment info saved to `deployments/base-sepolia.json`
- [x] ABIs exported to `frontend/abi/`

---

## 📁 Files Created

### Deployment Data
- **`deployments/base-sepolia.json`** - Complete deployment configuration (addresses, chain info, etc.)

### ABIs for Frontend
All contract ABIs have been exported to `frontend/abi/`:
- `MarketV2.json` (28KB) - Main market contract
- `MarketView.json` (2.6KB) - Read-only view contract
- `QUSD.json` (9.6KB) - Virtual USD token
- `DecisionTokenERC20.json` (10KB) - YES/NO decision tokens
- `DecisionTokenFactory.json` (2.8KB) - Token factory
- `SimpleResolver.json` (5.2KB) - Market resolver

---

## 🚀 Frontend Integration Quick Start

### 1. Copy Contract Addresses

Use the addresses from `deployments/base-sepolia.json` or the table above.

### 2. Import ABIs in Your Frontend

```typescript
import MarketABI from './abi/MarketV2.json';
import MarketViewABI from './abi/MarketView.json';
import QUSDABI from './abi/QUSD.json';
import DecisionTokenABI from './abi/DecisionTokenERC20.json';

// Initialize with ethers.js / viem
const market = new ethers.Contract(
  "0xa4Fc3e9739a2d991fDC4565607FEAb8A4ca1DDd8",
  MarketABI,
  signer
);
```

### 3. Key Functions to Integrate

#### Creating a Market
```typescript
await market.createMarket(
  marketTokenAddress,
  minDeposit,
  deadline,
  resolverAddress
);
```

#### Creating a Proposal
```typescript
await market.createProposal(marketId, description);
```

#### Minting YES/NO Tokens
```typescript
await market.mintYesNo(proposalId, amount);
```

#### Reading Market Data (Using MarketView)
```typescript
const marketView = new ethers.Contract(
  "0x54e985AA34F6C95cF3Cc0fbe15FAA16A4eb24174",
  MarketViewABI,
  provider
);

// Get all markets
const markets = await marketView.getAllMarkets();

// Get market details
const marketDetails = await marketView.getMarketDetails(marketId);

// Get proposals for a market
const proposals = await marketView.getMarketProposals(marketId);
```

---

## 🧪 Testing the Deployment

### Test QUSD Name
```bash
cast call 0x2c6E9a46db09a9bB8756375B1a98161182a6DeCe "name()" \
  --rpc-url https://base-sepolia.g.alchemy.com/v2/wfTWOqX-tfO2ahOiD3rCXzscObxKVms-
```

### Test Market Owner
```bash
cast call 0xa4Fc3e9739a2d991fDC4565607FEAb8A4ca1DDd8 "owner()" \
  --rpc-url https://base-sepolia.g.alchemy.com/v2/wfTWOqX-tfO2ahOiD3rCXzscObxKVms-
```

### Test QUSD Minter
```bash
cast call 0x2c6E9a46db09a9bB8756375B1a98161182a6DeCe "minter()" \
  --rpc-url https://base-sepolia.g.alchemy.com/v2/wfTWOqX-tfO2ahOiD3rCXzscObxKVms-
# Should return: 0xa4Fc3e9739a2d991fDC4565607FEAb8A4ca1DDd8 (Market address)
```

---

## 📚 Documentation

For detailed information about the system architecture and usage:

- **Architecture**: `docs/ARCHITECTURE.md`
- **Contract Summary**: `docs/CONTRACT_SUMMARY.md`
- **Frontend Integration**: `docs/FRONTEND_INTEGRATION.md`
- **Complete System Summary**: `docs/COMPLETE_SYSTEM_SUMMARY.md`

---

## 🔗 Useful Links

- **Base Sepolia Faucet**: https://www.alchemy.com/faucets/base-sepolia
- **Base Sepolia Explorer**: https://sepolia.basescan.org/
- **Your Deployer**: https://sepolia.basescan.org/address/0x89fEdB2167197199Fd069122e5351A1C779F91B8

---

## 🎯 What's Next?

Your Qlick prediction market is now fully deployed and ready for frontend integration! The system includes:

1. ✅ **Full market lifecycle** - Create, deposit, propose, trade, resolve, redeem
2. ✅ **QUSD token** - Virtual USD for all market operations
3. ✅ **YES/NO tokens** - ERC20 decision tokens for each proposal
4. ✅ **Uniswap v4 integration** - Automated liquidity pools for trading
5. ✅ **Market resolution** - Oracle-based outcome verification
6. ✅ **Frontend-ready** - MarketView contract for easy data access

Start building your frontend using the addresses and ABIs provided above!

---

**Need Help?** Check the documentation files or review the contract source code in `src/`.

