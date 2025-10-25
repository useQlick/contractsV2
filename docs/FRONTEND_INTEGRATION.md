// Frontend Integration Guide - Qlick Prediction Markets

## 🚀 Complete Production Integration Guide

This guide shows you how to integrate the Qlick prediction market system with your frontend application.

## 📋 Table of Contents

- [Contract Addresses](#contract-addresses)
- [Quick Start](#quick-start)
- [Core Workflows](#core-workflows)
- [Frontend Helper Contract](#frontend-helper-contract)
- [Event Listening](#event-listening)
- [TypeScript/JavaScript Examples](#typescript-javascript-examples)
- [React Integration](#react-integration)
- [Advanced Features](#advanced-features)

## 📍 Contract Addresses

After deployment, you'll have these contract addresses (example):

```json
{
  "market": "0x...",           // MarketV2 - main contract
  "qusd": "0x...",             // QUSD token
  "tokenFactory": "0x...",     // DecisionTokenFactory
  "resolver": "0x...",         // SimpleResolver (dev) or production oracle
  "hook": "0x...",             // MarketUtilsSwapHook
  "marketView": "0x...",       // MarketView - frontend helper
  "poolManager": "0x...",      // Uniswap v4 PoolManager
  "positionManager": "0x..."   // Uniswap v4 PositionManager
}
```

## 🎯 Quick Start

### 1. Install Dependencies

```bash
npm install ethers wagmi viem @tanstack/react-query
```

### 2. Setup Contract ABIs

Export ABIs from compiled contracts:

```bash
forge inspect MarketV2 abi > frontend/abi/MarketV2.json
forge inspect MarketView abi > frontend/abi/MarketView.json
forge inspect QUSD abi > frontend/abi/QUSD.json
forge inspect DecisionTokenERC20 abi > frontend/abi/DecisionTokenERC20.json
```

### 3. Initialize Contract Instances

```typescript
import { ethers } from 'ethers';
import MarketV2ABI from './abi/MarketV2.json';
import MarketViewABI from './abi/MarketView.json';

const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

const market = new ethers.Contract(
  MARKET_ADDRESS,
  MarketV2ABI,
  signer
);

const marketView = new ethers.Contract(
  MARKET_VIEW_ADDRESS,
  MarketViewABI,
  provider // read-only
);
```

## 🔄 Core Workflows

### Workflow 1: Create a Market

```typescript
async function createMarket(
  marketToken: string,    // ERC20 token address (e.g., USDC)
  minDeposit: bigint,     // Minimum deposit (e.g., 1000e18)
  deadline: number,       // Unix timestamp
  resolver: string        // Resolver contract address
): Promise<number> {
  const tx = await market.createMarket(
    marketToken,
    minDeposit,
    deadline,
    resolver
  );
  
  const receipt = await tx.wait();
  
  // Get marketId from event
  const event = receipt.events?.find(e => e.event === 'MarketCreated');
  const marketId = event?.args?.marketId;
  
  return marketId;
}
```

### Workflow 2: Deposit to Market

```typescript
async function depositToMarket(
  marketId: number,
  amount: bigint,
  marketToken: string
): Promise<void> {
  // 1. Approve market token
  const token = new ethers.Contract(marketToken, ERC20_ABI, signer);
  const approveTx = await token.approve(MARKET_ADDRESS, amount);
  await approveTx.wait();
  
  // 2. Deposit
  const depositTx = await market.depositToMarket(marketId, amount);
  await depositTx.wait();
}
```

### Workflow 3: Create a Proposal

```typescript
async function createProposal(
  marketId: number,
  description: string
): Promise<{proposalId: number, yesToken: string, noToken: string}> {
  const tx = await market.createProposal(marketId, description);
  const receipt = await tx.wait();
  
  // Get proposal data from event
  const event = receipt.events?.find(e => e.event === 'ProposalCreated');
  
  return {
    proposalId: event?.args?.proposalId,
    yesToken: event?.args?.yesToken,
    noToken: event?.args?.noToken
  };
}
```

### Workflow 4: Mint YES/NO Tokens

```typescript
async function mintYesNoTokens(
  proposalId: number,
  amount: bigint,
  marketToken: string
): Promise<void> {
  // 1. Approve market token
  const token = new ethers.Contract(marketToken, ERC20_ABI, signer);
  const approveTx = await token.approve(MARKET_ADDRESS, amount);
  await approveTx.wait();
  
  // 2. Mint tokens
  const mintTx = await market.mintYesNo(proposalId, amount);
  await mintTx.wait();
  
  // User now has:
  // - amount YES tokens
  // - amount NO tokens  
  // - amount QUSD tokens
}
```

### Workflow 5: Trade on Uniswap

```typescript
// After minting, users can trade YES/NO tokens on Uniswap v4 pools
// Example: Swap QUSD for YES tokens

async function swapQUSDForYES(
  yesToken: string,
  qusdAmount: bigint,
  minYESOut: bigint
): Promise<void> {
  // Use Uniswap v4 router
  const routerParams = {
    // ... Uniswap v4 swap parameters
    // See Uniswap v4 documentation for exact format
  };
  
  const tx = await uniswapRouter.swap(routerParams);
  await tx.wait();
}
```

### Workflow 6: Graduate Market

```typescript
async function graduateMarket(marketId: number): Promise<number> {
  const tx = await market.graduateMarket(marketId);
  const receipt = await tx.wait();
  
  // Get accepted proposal
  const event = receipt.events?.find(e => e.event === 'MarketGraduated');
  const acceptedProposalId = event?.args?.acceptedProposalId;
  
  return acceptedProposalId;
}
```

### Workflow 7: Resolve Market

```typescript
async function resolveMarket(
  marketId: number,
  yesOrNo: boolean,
  proof: string = "0x"
): Promise<void> {
  // First, set outcome in resolver (if using SimpleResolver)
  const acceptedProposal = await market.getAcceptedProposal(marketId);
  const resolverTx = await resolver.setOutcome(acceptedProposal, yesOrNo);
  await resolverTx.wait();
  
  // Then resolve market
  const resolveTx = await market.resolveMarket(marketId, yesOrNo, proof);
  await resolveTx.wait();
}
```

### Workflow 8: Redeem Rewards

```typescript
async function redeemRewards(marketId: number): Promise<bigint> {
  const tx = await market.redeemRewards(marketId);
  const receipt = await tx.wait();
  
  // Get reward amount from event
  const event = receipt.events?.find(e => e.event === 'RewardsRedeemed');
  const amount = event?.args?.amount;
  
  return amount;
}
```

## 📊 Frontend Helper Contract (MarketView)

Use `MarketView` for efficient data fetching:

### Get Market Information

```typescript
interface MarketInfo {
  marketId: bigint;
  marketToken: string;
  minDeposit: bigint;
  deadline: bigint;
  resolver: string;
  status: number; // 0=OPEN, 1=PROPOSAL_ACCEPTED, 2=RESOLVED_YES, 3=RESOLVED_NO
  totalDeposits: bigint;
  proposalCount: bigint;
  timeRemaining: bigint;
  canGraduate: boolean;
}

async function getMarketInfo(marketId: number): Promise<MarketInfo> {
  return await marketView.getMarketInfo(marketId);
}
```

### Get Proposal Information

```typescript
interface ProposalInfo {
  proposalId: bigint;
  marketId: bigint;
  creator: string;
  description: string;
  depositAmount: bigint;
  createdAt: bigint;
  yesToken: string;
  noToken: string;
  yesPrice: bigint; // Current price (scaled by 1e18)
  noPrice: bigint;
  yesLiquidity: bigint;
  noLiquidity: bigint;
  isAccepted: boolean;
}

async function getProposalInfo(proposalId: number): Promise<ProposalInfo> {
  return await marketView.getProposalInfo(proposalId);
}
```

### Get All Proposals for a Market

```typescript
async function getMarketProposals(
  marketId: number,
  limit: number = 10,
  offset: number = 0
): Promise<ProposalInfo[]> {
  return await marketView.getMarketProposals(marketId, limit, offset);
}
```

### Get User Position

```typescript
interface UserPosition {
  marketDeposit: bigint;
  yesBalance: bigint;
  noBalance: bigint;
  qusdBalance: bigint;
  potentialWinnings: bigint;
  canRedeem: boolean;
}

async function getUserPosition(
  proposalId: number,
  marketId: number,
  userAddress: string
): Promise<UserPosition> {
  return await marketView.getUserPosition(proposalId, marketId, userAddress);
}
```

### Get Leaderboard

```typescript
async function getLeaderboard(
  marketId: number,
  limit: number = 10
): Promise<ProposalInfo[]> {
  return await marketView.getLeaderboard(marketId, limit);
}
```

### Get Quote for Swap

```typescript
async function quoteSwap(
  proposalId: number,
  buyYes: boolean,
  amountIn: bigint
): Promise<bigint> {
  return await marketView.quoteSwap(proposalId, buyYes, amountIn);
}
```

## 🔔 Event Listening

Listen to contract events for real-time updates:

```typescript
// Market created
market.on("MarketCreated", (marketId, marketToken, minDeposit, deadline, resolver) => {
  console.log(`New market created: ${marketId}`);
  // Update UI
});

// Proposal created
market.on("ProposalCreated", (proposalId, marketId, creator, description) => {
  console.log(`New proposal: ${proposalId} - ${description}`);
  // Update proposal list
});

// Price updated
market.on("PriceUpdated", (proposalId, price, tick) => {
  console.log(`Price updated for proposal ${proposalId}: ${price}`);
  // Update price chart
});

// Market graduated
market.on("MarketGraduated", (marketId, acceptedProposalId, maxPrice) => {
  console.log(`Market ${marketId} graduated. Winner: ${acceptedProposalId}`);
  // Show graduation notification
});

// Market resolved
market.on("MarketResolved", (marketId, acceptedProposalId, yesOrNo) => {
  console.log(`Market resolved. YES won: ${yesOrNo}`);
  // Enable redemption
});
```

## ⚛️ React Integration Example

### Custom Hook for Market Data

```typescript
// useMarketInfo.ts
import { useEffect, useState } from 'react';
import { useContract, useProvider } from 'wagmi';

export function useMarketInfo(marketId: number) {
  const [marketInfo, setMarketInfo] = useState<MarketInfo | null>(null);
  const [loading, setLoading] = useState(true);
  
  const provider = useProvider();
  const marketView = useContract({
    address: MARKET_VIEW_ADDRESS,
    abi: MarketViewABI,
    signerOrProvider: provider,
  });

  useEffect(() => {
    async function fetch() {
      setLoading(true);
      try {
        const info = await marketView?.getMarketInfo(marketId);
        setMarketInfo(info);
      } catch (error) {
        console.error('Failed to fetch market info:', error);
      } finally {
        setLoading(false);
      }
    }

    if (marketId && marketView) {
      fetch();
    }
  }, [marketId, marketView]);

  return { marketInfo, loading };
}
```

### Market List Component

```typescript
// MarketList.tsx
import { useMarketInfo } from './hooks/useMarketInfo';

export function MarketList() {
  // In production, fetch list of market IDs from an indexer or subgraph
  const marketIds = [1, 2, 3, 4, 5];

  return (
    <div className="market-list">
      {marketIds.map(id => (
        <MarketCard key={id} marketId={id} />
      ))}
    </div>
  );
}

function MarketCard({ marketId }: { marketId: number }) {
  const { marketInfo, loading } = useMarketInfo(marketId);

  if (loading) return <div>Loading...</div>;
  if (!marketInfo) return <div>Error loading market</div>;

  return (
    <div className="market-card">
      <h3>Market #{marketId}</h3>
      <div>Status: {['OPEN', 'GRADUATED', 'RESOLVED_YES', 'RESOLVED_NO'][marketInfo.status]}</div>
      <div>Proposals: {marketInfo.proposalCount.toString()}</div>
      <div>Time Remaining: {marketInfo.timeRemaining.toString()}s</div>
      {marketInfo.canGraduate && (
        <button onClick={() => handleGraduate(marketId)}>
          Graduate Market
        </button>
      )}
    </div>
  );
}
```

### Proposal List Component

```typescript
// ProposalList.tsx
export function ProposalList({ marketId }: { marketId: number }) {
  const [proposals, setProposals] = useState<ProposalInfo[]>([]);

  useEffect(() => {
    async function fetch() {
      const data = await marketView.getMarketProposals(marketId, 100, 0);
      setProposals(data);
    }
    fetch();
  }, [marketId]);

  return (
    <div className="proposal-list">
      {proposals.map(proposal => (
        <ProposalCard key={proposal.proposalId} proposal={proposal} />
      ))}
    </div>
  );
}

function ProposalCard({ proposal }: { proposal: ProposalInfo }) {
  const yesPrice = ethers.utils.formatUnits(proposal.yesPrice, 18);
  const noPrice = ethers.utils.formatUnits(proposal.noPrice, 18);

  return (
    <div className={`proposal-card ${proposal.isAccepted ? 'accepted' : ''}`}>
      <h4>{proposal.description}</h4>
      <div className="prices">
        <div className="yes-price">YES: {yesPrice}</div>
        <div className="no-price">NO: {noPrice}</div>
      </div>
      <div className="liquidity">
        <div>YES Liquidity: {ethers.utils.formatEther(proposal.yesLiquidity)}</div>
        <div>NO Liquidity: {ethers.utils.formatEther(proposal.noLiquidity)}</div>
      </div>
      {proposal.isAccepted && <span className="badge">ACCEPTED</span>}
    </div>
  );
}
```

## 🎨 UI/UX Recommendations

### Market List Page
- Show all active markets
- Filter by status (Open, Graduated, Resolved)
- Sort by deadline, total deposits, proposal count
- Real-time countdown timers

### Market Detail Page
- Market information (status, deadline, total deposits)
- Proposal list with current prices
- Price charts for each proposal
- Deposit button
- Create proposal button

### Proposal Detail Page
- Proposal description and metadata
- YES/NO price charts
- Trading interface
  - Mint YES/NO tokens
  - Swap on Uniswap
  - Redeem token pairs
- Liquidity information
- Creator information

### User Dashboard
- Active positions across all markets
- Deposited funds
- Token balances (YES, NO, QUSD)
- Potential winnings
- Redemption interface

## 📈 Advanced Features

### Real-Time Price Updates

Use The Graph or a custom indexer:

```graphql
subscription {
  priceUpdates(where: {proposalId: "1"}) {
    proposalId
    price
    tick
    timestamp
  }
}
```

### Price Charts

Use recharts or similar:

```typescript
import { LineChart, Line, XAxis, YAxis } from 'recharts';

function PriceChart({ proposalId }: { proposalId: number }) {
  const [priceHistory, setPriceHistory] = useState([]);

  // Fetch price history from indexer
  useEffect(() => {
    // ... fetch data
  }, [proposalId]);

  return (
    <LineChart data={priceHistory}>
      <XAxis dataKey="timestamp" />
      <YAxis />
      <Line type="monotone" dataKey="yesPrice" stroke="#00ff00" />
      <Line type="monotone" dataKey="noPrice" stroke="#ff0000" />
    </LineChart>
  );
}
```

### Notifications

```typescript
// Push notifications when:
// - Market deadline approaching
// - New proposal created
// - Market graduated
// - Market resolved
// - User has claimable rewards

function useNotifications(userAddress: string) {
  useEffect(() => {
    market.on("MarketGraduated", (marketId) => {
      // Check if user has positions
      // Show notification
    });

    market.on("MarketResolved", (marketId) => {
      // Check if user can redeem
      // Show notification
    });
  }, [userAddress]);
}
```

## 🔐 Security Considerations

1. **Always approve exact amounts** - Don't approve MAX_UINT256
2. **Validate user inputs** - Check amounts, deadlines, addresses
3. **Handle errors gracefully** - Show user-friendly messages
4. **Use read-only provider for queries** - Only use signer for transactions
5. **Verify contract addresses** - Check against official deployments
6. **Test on testnet first** - Don't deploy directly to mainnet

## 📚 Additional Resources

- Contract ABIs in `/frontend/abi/`
- Deployment addresses in `/deployments/latest.json`
- Full contract documentation in `/docs/`
- Example frontend in `/examples/frontend/`

## 🆘 Support

For issues or questions:
1. Check the documentation
2. Review example code
3. Open an issue on GitHub
4. Join the Discord community

---

**Ready for Production!** 🚀

This integration guide provides everything needed to build a complete prediction market frontend with Qlick.

