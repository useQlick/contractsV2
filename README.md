# Qlick Prediction Markets

> Decentralized prediction markets powered by Uniswap v4 and QUSD

Qlick enables users to create prediction markets, propose outcomes, trade positions, and resolve markets based on real-world events using automated market makers.

## 🌟 Features

- **Market Creation**: Anyone can create prediction markets with custom parameters
- **Proposal System**: Users deposit tokens to propose potential outcomes
- **Automated Trading**: Integrated with Uniswap v4 for seamless trading
- **Price Discovery**: Automatically selects highest-priced proposal at deadline
- **Oracle Integration**: Flexible resolver system for outcome verification
- **QUSD Integration**: Virtual USD token (QUSD) for consistent liquidity pairs
- **Secure Token Mechanics**: Decision tokens (YES/NO) with granular access control

## 📋 Table of Contents

- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contract Overview](#contract-overview)
- [Security](#security)
- [Development](#development)
- [Production Considerations](#production-considerations)

## 🏗️ Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed system design.

### Market Lifecycle

```
1. CREATE MARKET
   ↓
2. USERS DEPOSIT → CREATE PROPOSALS → MINT YES/NO TOKENS
   ↓
3. TRADING (Uniswap v4 pools track prices)
   ↓
4. DEADLINE PASSES → GRADUATION (highest YES price selected)
   ↓
5. ORACLE VERIFICATION → RESOLUTION
   ↓
6. WINNERS REDEEM REWARDS
```

### Key Contracts

| Contract | Purpose |
|----------|---------|
| `Market.sol` | Core engine managing lifecycle |
| `QUSD.sol` | Virtual USD token (ERC20) |
| `DecisionToken.sol` | YES/NO position tokens |
| `MarketUtilsSwapHook.sol` | Uniswap v4 hook for price tracking |
| `SimpleResolver.sol` | Oracle resolver (dev/testing) |

## 🚀 Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity ^0.8.26
- Git

### Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd contracts

# Install dependencies
forge install

# Build contracts
forge build
```

### Dependencies

The project uses:
- OpenZeppelin Contracts (access control, ERC20, security)
- Uniswap v4 Core (pool management)
- Uniswap v4 Periphery (position management)
- Uniswap Hooks (BaseHook implementation)

## 📖 Usage

### Creating a Market

```solidity
// 1. Deploy a market token (e.g., USDC)
// 2. Deploy a resolver
// 3. Create the market

uint256 marketId = market.createMarket(
    marketToken,    // ERC20 token for deposits
    1000e18,        // Minimum deposit to create proposals
    block.timestamp + 7 days,  // Deadline
    resolverAddress // Oracle resolver
);
```

### Participating

```solidity
// 1. Deposit tokens
market.depositToMarket(marketId, 1000e18);

// 2. Create a proposal
uint256 proposalId = market.createProposal(
    marketId,
    "Proposal description"
);
```

### Trading

```solidity
// Mint YES/NO token pairs + QUSD
market.mintYesNo(proposalId, 100e18);

// Trade on Uniswap v4 pools
// YES/QUSD pool and NO/QUSD pool

// Redeem pairs back to market tokens
market.redeemYesNo(proposalId, 100e18);
```

### Graduation & Resolution

```solidity
// After deadline, graduate the market
market.graduateMarket(marketId);

// Set outcome in resolver (owner only in SimpleResolver)
resolver.setOutcome(proposalId, true); // true = YES wins

// Resolve the market
market.resolveMarket(marketId, true, "");
```

### Claiming Rewards

```solidity
// After resolution, winners claim
market.redeemRewards(marketId);
```

## 🧪 Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/Market.t.sol

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Test Files

- `test/Market.t.sol` - Core market functionality (15+ tests)
- `test/tokens/QUSD.t.sol` - QUSD token tests
- `test/tokens/DecisionToken.t.sol` - Decision token tests
- `test/resolvers/SimpleResolver.t.sol` - Resolver tests

### Test Coverage

- ✅ Market creation and configuration
- ✅ Deposit mechanics
- ✅ Proposal creation with token minting
- ✅ YES/NO token minting and redemption
- ✅ Market graduation
- ✅ Oracle resolution
- ✅ Reward redemption
- ✅ Edge cases (insufficient deposits, wrong outcomes, etc.)
- ✅ Multiple proposals per market
- ✅ Access control

## 🚢 Deployment

### Local/Testnet Deployment

```bash
# Set environment variables
cp .env.example .env
# Edit .env with your values

# Deploy with mocks (for testing)
forge script script/DeployMarket.s.sol --rpc-url <RPC_URL> --broadcast

# Deploy to testnet
forge script script/DeployMarket.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

### Environment Variables

```bash
PRIVATE_KEY=<your-private-key>
USE_MOCKS=true  # Set to false for production with real Uniswap v4
POOL_MANAGER=<uniswap-pool-manager-address>
POSITION_MANAGER=<uniswap-position-manager-address>
```

### Deployment Steps

1. Deploy QUSD token
2. Deploy DecisionToken
3. Deploy Market contract
4. Deploy MarketUtilsSwapHook
5. Set Market as minter for QUSD and DecisionToken
6. Deploy resolver(s)

The deployment script handles this automatically.

## 📚 Contract Overview

### Market.sol

Main contract managing the prediction market lifecycle.

**Key Functions:**
- `createMarket()` - Create a new market
- `depositToMarket()` - Deposit tokens to participate
- `createProposal()` - Create outcome proposal
- `mintYesNo()` / `redeemYesNo()` - Mint/redeem token pairs
- `graduateMarket()` - Select winning proposal
- `resolveMarket()` - Verify and finalize outcome
- `redeemRewards()` - Claim winnings

### QUSD.sol

Virtual USD token used for liquidity pairs.

**Features:**
- ERC20-compliant
- Mint/burn by Market contract only
- Standard transfers enabled

### DecisionToken.sol

Multi-dimensional token for YES/NO positions.

**Structure:**
- Balance: `account => proposalId => tokenType => amount`
- Types: YES or NO
- Mint/burn/transfer by Market contract only

### MarketUtilsSwapHook.sol

Uniswap v4 hook for price tracking.

**Hooks:**
- `beforeSwap()` - Validate market state
- `afterSwap()` - Update price tracking

### SimpleResolver.sol

⚠️ **Development Only** - Centralized resolver.

**Functions:**
- `setOutcome()` - Owner sets verified outcome
- `verifyResolution()` - Called by Market to verify proof

## 🔒 Security

### Access Control

- **QUSD & DecisionToken**: Only Market contract can mint/burn
- **Market Operations**: Public but state-gated
- **Resolver**: Owner-controlled (in SimpleResolver)

### Safety Features

- ReentrancyGuard on all token operations
- SafeERC20 for external token transfers
- Zero address validation
- Deadline enforcement
- Market status checks
- Proof verification

### Known Considerations

1. **SimpleResolver is centralized** - Replace with decentralized oracle in production
2. **Pool initialization is simplified** - Needs full Uniswap v4 integration
3. **Price tracking is estimated** - Production needs accurate tick calculation

### Auditing

⚠️ **This code has not been audited.** 

Do not use in production without:
1. Professional security audit
2. Comprehensive testing on testnet
3. Decentralized resolver implementation
4. Full Uniswap v4 integration

## 🛠️ Development

### Project Structure

```
contracts/
├── src/
│   ├── Market.sol                 # Core market engine
│   ├── MarketUtilsSwapHook.sol   # Uniswap v4 hook
│   ├── tokens/
│   │   ├── QUSD.sol              # Virtual USD token
│   │   └── DecisionToken.sol     # YES/NO tokens
│   ├── resolvers/
│   │   └── SimpleResolver.sol    # Dev resolver
│   ├── interfaces/
│   │   ├── IMarket.sol
│   │   ├── IMarketResolver.sol
│   │   ├── IQUSD.sol
│   │   └── IDecisionToken.sol
│   ├── common/
│   │   └── MarketData.sol        # Structs and enums
│   └── utils/
│       └── Id.sol                # ID generator
├── test/
│   ├── Market.t.sol
│   ├── tokens/
│   ├── resolvers/
│   └── mocks/
├── script/
│   └── DeployMarket.s.sol
└── ARCHITECTURE.md
```

### Building

```bash
forge build
```

### Formatting

```bash
forge fmt
```

### Linting

```bash
# Check for issues
forge test --show-progress

# Static analysis (if slither installed)
slither .
```

## 🚀 Production Considerations

### 1. Decentralized Resolver

Replace `SimpleResolver` with:

**Option A: Chainlink Oracles**
```solidity
contract ChainlinkResolver is IMarketResolver {
    AggregatorV3Interface public priceFeed;
    
    function verifyResolution(uint256 proposalId, bool yesOrNo, bytes calldata proof) 
        external view override 
    {
        // Fetch and verify Chainlink data
    }
}
```

**Option B: UMA DVM**
```solidity
contract UMAResolver is IMarketResolver {
    OptimisticOracleV3Interface public oracle;
    
    function verifyResolution(uint256 proposalId, bool yesOrNo, bytes calldata proof) 
        external view override 
    {
        // Query UMA dispute resolution
    }
}
```

**Option C: Signature Verification**
```solidity
contract SignatureResolver is IMarketResolver {
    address public trustedSigner;
    
    function verifyResolution(uint256 proposalId, bool yesOrNo, bytes calldata proof) 
        external view override 
    {
        // Verify ECDSA signature from trusted oracle
        (bytes32 r, bytes32 s, uint8 v) = abi.decode(proof, (bytes32, bytes32, uint8));
        // Validate signature...
    }
}
```

### 2. Complete Uniswap v4 Integration

Current implementation has placeholder pool initialization. Production needs:

- Proper Currency wrapping for DecisionTokens
- Real pool initialization with correct parameters
- Position NFT management
- Liquidity tracking and removal
- Fee handling

### 3. Economic Improvements

- **Dynamic Fees**: Adjust based on volatility
- **Liquidity Incentives**: Reward liquidity providers
- **Slippage Protection**: Add max slippage parameters
- **Market Maker Rewards**: Incentivize proposal creators

### 4. Governance

- **Timelock**: Add delays for critical changes
- **Multi-sig**: Require multiple signers for sensitive operations
- **Upgradeability**: Consider proxy patterns
- **Emergency Pause**: Circuit breaker for emergencies

### 5. Gas Optimizations

- Batch operations where possible
- Use `calldata` instead of `memory` for read-only data
- Pack storage variables efficiently
- Consider EIP-1167 minimal proxies for repeated deployments

## 📝 License

MIT License - see [LICENSE](./LICENSE)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📧 Support

For questions and support:
- Open an issue on GitHub
- Check [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed design
- Review test files for usage examples

## 🎯 Roadmap

- [ ] Full Uniswap v4 integration
- [ ] Decentralized resolver implementations
- [ ] Frontend interface
- [ ] Subgraph for event indexing
- [ ] Multi-chain deployment
- [ ] Governance token
- [ ] Advanced market types (scalar, categorical)
- [ ] Market maker incentives
- [ ] Professional security audit

---

Built with ❤️ using Foundry and Uniswap v4

