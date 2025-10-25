# Qlick Prediction Market Architecture

## Overview

Qlick is a decentralized prediction market built on Uniswap v4, enabling users to create markets, propose outcomes, trade on predictions, and resolve markets based on real-world events.

## Core Components

### 1. Market.sol
**The Core Engine**

The `Market` contract manages the complete lifecycle of prediction markets:

#### Market Lifecycle States
- **OPEN**: Market is active, proposals can be created, trading is allowed
- **PROPOSAL_ACCEPTED**: Deadline passed, highest YES-priced proposal graduated
- **RESOLVED_YES**: Oracle verified the accepted proposal's YES outcome
- **RESOLVED_NO**: Oracle verified the accepted proposal's NO outcome

#### Key Functions

**Market Creation**
```solidity
createMarket(marketToken, minDeposit, deadline, resolver) → marketId
```
- Creates a new prediction market
- Sets minimum deposit requirement for creating proposals
- Defines market deadline and resolver contract

**Participation**
```solidity
depositToMarket(marketId, amount)
```
- Users deposit market tokens (e.g., USDC) to participate
- Deposits must meet `minDeposit` to create proposals

**Proposal Creation**
```solidity
createProposal(marketId, description) → proposalId
```
- Requires `minDeposit` from user's balance
- Mints YES/NO DecisionTokens (half to user, half for liquidity)
- Mints QUSD equal to deposit amount
- Creates two Uniswap v4 pools: YES/QUSD and NO/QUSD
- Seeds pools with initial liquidity

**Trading**
```solidity
mintYesNo(proposalId, amount)    // Buy decision tokens
redeemYesNo(proposalId, amount)  // Redeem token pairs
```
- Users can mint YES+NO token pairs by depositing market tokens
- Pairs can be redeemed back to market tokens anytime
- Trading happens on Uniswap v4 pools

**Graduation**
```solidity
graduateMarket(marketId)
```
- Called after deadline passes
- Selects proposal with highest observed YES price
- Sets status to PROPOSAL_ACCEPTED
- Records accepted proposal ID

**Resolution**
```solidity
resolveMarket(marketId, yesOrNo, proof)
```
- Calls resolver to verify proof of outcome
- Sets final status: RESOLVED_YES or RESOLVED_NO
- Only works after graduation

**Redemption**
```solidity
redeemRewards(marketId)
```
- Users burn winning tokens + QUSD
- Receive market tokens as rewards
- Only works after resolution

### 2. QUSD.sol
**Virtual USD Token**

- ERC20 token representing virtual USD
- Replaces VUSD from original spec
- Mintable/burnable only by Market contract
- Used for liquidity pairs: YES/QUSD and NO/QUSD

**Key Features**
- Owner-controlled minter address
- Only minter can mint/burn
- Standard ERC20 transfers allowed

### 3. DecisionToken.sol
**YES/NO Position Tokens**

- Represents trading positions in proposals
- Multi-dimensional balances: `account => proposalId => tokenType => balance`
- TokenType enum: YES or NO
- Mintable/burnable only by Market contract

**Key Features**
- Separate balances per proposal and token type
- Reentrancy-protected mint/burn/transfer
- Only minter (Market) can manipulate balances

### 4. MarketUtilsSwapHook.sol
**Uniswap v4 Integration**

A BaseHook implementation that:
- Validates swaps are from OPEN markets (beforeSwap)
- Tracks price movements via tick accumulation
- Updates Market contract with price data (afterSwap)
- Enables the Market to record highest YES prices

**Hook Permissions**
- `beforeSwap`: Validate market state
- `afterSwap`: Update price tracking

### 5. IMarketResolver.sol
**Oracle Interface**

Resolver contracts must implement:
```solidity
function verifyResolution(proposalId, yesOrNo, proof) external
```

**Expected Behavior**
- MUST revert if proof is invalid
- MUST revert if proof doesn't match claimed outcome
- If successful, Market finalizes the resolution

### 6. SimpleResolver.sol
**Development Resolver**

⚠️ **WARNING**: Centralized resolver for testing only!

- Owner can set outcomes directly
- No decentralization
- Perfect for development and testing
- Replace with decentralized oracle in production

**Production Alternatives**
- Chainlink oracles
- UMA DVM
- Signed message verification
- Multi-sig committees
- On-chain attestations

## Architecture Flow

### 1. Market Creation Flow
```
User → createMarket() → Market contract
  ↓
Market stored with:
  - marketToken (USDC, DAI, etc.)
  - minDeposit
  - deadline
  - resolver address
  - status: OPEN
```

### 2. Proposal Creation Flow
```
User → depositToMarket() → Market contract
  ↓ (deposit >= minDeposit)
User → createProposal() → Market contract
  ↓
Market actions:
  1. Deduct minDeposit from user's deposits
  2. Mint YES/NO tokens (50% user, 50% liquidity)
  3. Mint QUSD for liquidity
  4. Initialize YES/QUSD pool
  5. Initialize NO/QUSD pool
  6. Add liquidity to both pools
  7. Store proposal config
  8. Map pools to proposalId
```

### 3. Trading Flow
```
User → mintYesNo() → Market contract
  ↓
  1. Transfer market tokens from user
  2. Mint YES + NO tokens to user
  3. Mint QUSD to user
  
User → Swap on Uniswap v4 pool
  ↓
Hook → validateSwap() → Market contract
  ↓ (check market is OPEN)
Swap executes
  ↓
Hook → updatePostSwap() → Market contract
  ↓
Market updates highest YES price if exceeded
```

### 4. Graduation Flow
```
Time passes deadline
  ↓
Anyone → graduateMarket() → Market contract
  ↓
Market actions:
  1. Check deadline passed
  2. Find proposal with highest YES price
  3. Set status: PROPOSAL_ACCEPTED
  4. Store acceptedProposal ID
```

### 5. Resolution Flow
```
Oracle/Admin → setOutcome() → Resolver contract
  ↓
Anyone → resolveMarket(yesOrNo, proof) → Market contract
  ↓
Market calls:
  resolver.verifyResolution(proposalId, yesOrNo, proof)
  ↓ (reverts if invalid)
Market sets final status:
  RESOLVED_YES or RESOLVED_NO
```

### 6. Redemption Flow
```
User → redeemRewards() → Market contract
  ↓
Market checks:
  1. Market resolved?
  2. User has winning tokens or QUSD?
  ↓
Market actions:
  1. Calculate reward: winningTokens + QUSD
  2. Burn winning tokens
  3. Burn QUSD
  4. Transfer market tokens to user
```

## State Management

### Market States
```
OPEN → PROPOSAL_ACCEPTED → RESOLVED_YES/NO
         (graduateMarket)   (resolveMarket)
```

### Key Storage Mappings

**markets**
```solidity
mapping(uint256 => MarketConfig) markets
```
Stores all market configurations by ID.

**proposals**
```solidity
mapping(uint256 => ProposalConfig) proposals
```
Stores all proposal configurations by ID.

**marketMax**
```solidity
mapping(uint256 => MaxProposal) marketMax
```
Tracks highest YES price per market for graduation.

**acceptedProposals**
```solidity
mapping(uint256 => uint256) acceptedProposals
```
Maps marketId to accepted proposalId after graduation.

**deposits**
```solidity
mapping(uint256 => mapping(address => uint256)) deposits
```
Tracks user deposits per market.

**poolToProposal**
```solidity
mapping(PoolId => uint256) poolToProposal
```
Maps Uniswap pool IDs to proposal IDs.

## Price Tracking

### How Graduation Works

1. During trading, `updatePostSwap()` is called by the hook
2. Market calculates YES token price from pool tick
3. If price > current max for that market:
   - Update `marketMax[marketId].maxPrice`
   - Update `marketMax[marketId].proposalId`
   - Update `marketMax[marketId].maxTick`
4. At graduation, proposal with highest recorded YES price wins

### Tick to Price Conversion
```solidity
sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick)
price = (sqrtPriceX96 / 2^96)^2
```

## Security Considerations

### Access Control
- QUSD and DecisionToken: Only Market can mint/burn
- Market operations: Public, but state-gated
- Resolver: Only owner can set outcomes (SimpleResolver)

### Reentrancy Protection
- All token contracts use ReentrancyGuard
- Market uses nonReentrant on critical functions
- SafeERC20 for external token transfers

### Validation
- Zero address checks on deployment
- Deadline validation (must be future)
- Deposit requirements enforced
- Market status checks on all operations
- Proof verification in resolvers

### Known Limitations

1. **Pool Initialization**: Current implementation has placeholder pool initialization. Production needs full Uniswap v4 integration.

2. **Price Accuracy**: Tick estimation in hook is simplified. Production needs accurate tick calculation from pool state.

3. **Resolver Centralization**: SimpleResolver is centralized. Replace with decentralized oracle.

4. **Token Integration**: DecisionTokens need proper Currency wrapping for Uniswap v4.

## Testing Strategy

### Unit Tests
- Token minting/burning
- Market lifecycle transitions
- Deposit/withdrawal mechanics
- Access control enforcement

### Integration Tests
- Full market flow end-to-end
- Multiple proposals
- Price tracking
- Resolution mismatches

### Mock Contracts
- MockPoolManager: Simulates Uniswap v4 PoolManager
- MockPositionManager: Simulates position management
- MockERC20: Test market tokens

## Deployment

### Required Parameters
1. Pool Manager address (or deploy mock)
2. Position Manager address (or deploy mock)
3. Initial owner address

### Deployment Order
1. Deploy QUSD
2. Deploy DecisionToken
3. Deploy Market (with placeholder hook)
4. Deploy MarketUtilsSwapHook
5. Set Market as minter for QUSD and DecisionToken
6. Deploy resolver(s)

### Environment Variables
```bash
PRIVATE_KEY=<deployer-private-key>
USE_MOCKS=true  # false for production
POOL_MANAGER=<address>  # if USE_MOCKS=false
POSITION_MANAGER=<address>  # if USE_MOCKS=false
```

## Upgrading to Production

### 1. Decentralized Resolver
Replace SimpleResolver with:
- Chainlink oracles for data feeds
- UMA DVM for dispute resolution
- Signature verification for off-chain attestations
- Multi-sig committees with threshold

### 2. Full Uniswap v4 Integration
- Implement proper pool initialization
- Handle Currency wrapping for DecisionTokens
- Accurate tick calculation in hook
- Position NFT management
- Liquidity tracking

### 3. Token Improvements
- Make DecisionToken ERC20-compatible
- Add metadata (name, symbol per proposal)
- Enable direct Uniswap v4 integration

### 4. Economic Enhancements
- Dynamic tick spacing based on volatility
- Fee distribution mechanisms
- Liquidity mining incentives
- Slippage protection

### 5. Governance
- Timelock for critical functions
- Multi-sig for resolver management
- Upgradeable proxy patterns
- Emergency pause mechanism

## Gas Optimizations

- Use `unchecked` for safe arithmetic
- Pack structs efficiently
- Batch operations where possible
- Use events for off-chain indexing
- Minimize storage reads/writes

## Events

All contracts emit comprehensive events for:
- Market creation and state changes
- Deposits and withdrawals
- Proposal creation
- Token minting/burning
- Price updates
- Graduation and resolution
- Reward redemption

These enable:
- Off-chain indexing
- UI updates
- Analytics
- Auditing

## Conclusion

The Qlick prediction market system provides a robust, composable foundation for decentralized prediction markets with Uniswap v4 integration. The architecture supports:

- Multiple simultaneous markets
- Fair graduation via price discovery
- Flexible oracle integration
- Secure token mechanics
- Complete lifecycle management

Replace SimpleResolver and complete Uniswap v4 integration for production deployment.

