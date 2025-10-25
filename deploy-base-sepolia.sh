#!/bin/bash
# Qlick Market Deployment Script for Base Sepolia
# Run this script to deploy all contracts

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Qlick Market Deployment to Base Sepolia"
echo "==========================================="
echo ""

# Configuration
export RPC_URL="https://base-sepolia.g.alchemy.com/v2/wfTWOqX-tfO2ahOiD3rCXzscObxKVms-"
export PRIVATE_KEY="0x9d75962544708d5cd5896b138ff1d8ae64e11a64e9fd3cfeb9504fb4835bea78"
export POOL_MANAGER="0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408"
export POSITION_MANAGER="0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80"

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo "0x89fEdB2167197199Fd069122e5351A1C779F91B8")
echo -e "${GREEN}Deployer:${NC} $DEPLOYER"

# Skip balance check due to Foundry networking issue on some systems
echo -e "${GREEN}RPC:${NC} Base Sepolia"
echo ""

# Deploy QUSD
echo -e "${YELLOW}[1/6]${NC} Deploying QUSD..."
QUSD_OUTPUT=$(forge create src/tokens/QUSD.sol:QUSD \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --broadcast \
  --constructor-args "$DEPLOYER" 2>&1)
QUSD=$(echo "$QUSD_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$QUSD" ]; then
    echo -e "${RED}❌ QUSD deployment failed!${NC}"
    echo "$QUSD_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ QUSD:${NC} $QUSD"
echo ""

# Deploy TokenFactory (with placeholder)
echo -e "${YELLOW}[2/6]${NC} Deploying DecisionTokenFactory (placeholder)..."
FACTORY_TEMP_OUTPUT=$(forge create src/tokens/DecisionTokenFactory.sol:DecisionTokenFactory \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --broadcast \
  --constructor-args "0x0000000000000000000000000000000000000000" 2>&1)
FACTORY_TEMP=$(echo "$FACTORY_TEMP_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$FACTORY_TEMP" ]; then
    echo -e "${RED}❌ TokenFactory deployment failed!${NC}"
    echo "$FACTORY_TEMP_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ TokenFactory (temp):${NC} $FACTORY_TEMP"
echo ""

# Deploy MarketV2
echo -e "${YELLOW}[3/6]${NC} Deploying MarketV2 (this may take a minute, large contract)..."
MARKET_OUTPUT=$(forge create src/MarketV2.sol:MarketV2 \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --broadcast \
  --constructor-args "$POOL_MANAGER" "$POSITION_MANAGER" "$QUSD" "$FACTORY_TEMP" "0x0000000000000000000000000000000000000000" "$DEPLOYER" 2>&1)
MARKET=$(echo "$MARKET_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$MARKET" ]; then
    echo -e "${RED}❌ Market deployment failed!${NC}"
    echo "$MARKET_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ Market:${NC} $MARKET"
echo ""

# Deploy TokenFactory (correct)
echo -e "${YELLOW}[4/6]${NC} Deploying DecisionTokenFactory (with Market address)..."
FACTORY_OUTPUT=$(forge create src/tokens/DecisionTokenFactory.sol:DecisionTokenFactory \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --broadcast \
  --constructor-args "$MARKET" 2>&1)
FACTORY=$(echo "$FACTORY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$FACTORY" ]; then
    echo -e "${RED}❌ TokenFactory deployment failed!${NC}"
    echo "$FACTORY_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ TokenFactory:${NC} $FACTORY"
echo ""

# Deploy SimpleResolver
echo -e "${YELLOW}[5/6]${NC} Deploying SimpleResolver..."
RESOLVER_OUTPUT=$(forge create src/resolvers/SimpleResolver.sol:SimpleResolver \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --broadcast \
  --constructor-args "$DEPLOYER" 2>&1)
RESOLVER=$(echo "$RESOLVER_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$RESOLVER" ]; then
    echo -e "${RED}❌ Resolver deployment failed!${NC}"
    echo "$RESOLVER_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ Resolver:${NC} $RESOLVER"
echo ""

# Deploy MarketView
echo -e "${YELLOW}[6/6]${NC} Deploying MarketView (this may take a minute, large contract)..."
VIEW_OUTPUT=$(forge create src/MarketView.sol:MarketView \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --broadcast \
  --constructor-args "$MARKET" "$POOL_MANAGER" 2>&1)
VIEW=$(echo "$VIEW_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$VIEW" ]; then
    echo -e "${RED}❌ MarketView deployment failed!${NC}"
    echo "$VIEW_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ MarketView:${NC} $VIEW"
echo ""

# Configure permissions
echo -e "${YELLOW}[Config]${NC} Setting QUSD minter to Market..."
cast send $QUSD "setMinter(address)" $MARKET \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --gas-limit 100000 > /dev/null 2>&1

echo -e "${GREEN}✅ QUSD minter configured${NC}"
echo ""

# Save deployment addresses
mkdir -p deployments
cat > deployments/base-sepolia.json << EOF
{
  "network": "base-sepolia",
  "chainId": 84532,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployer": "$DEPLOYER",
  "contracts": {
    "market": "$MARKET",
    "qusd": "$QUSD",
    "tokenFactory": "$FACTORY",
    "resolver": "$RESOLVER",
    "marketView": "$VIEW",
    "poolManager": "$POOL_MANAGER",
    "positionManager": "$POSITION_MANAGER"
  },
  "uniswapV4": {
    "poolManager": "$POOL_MANAGER",
    "positionManager": "$POSITION_MANAGER",
    "universalRouter": "0x492e6456d9528771018deb9e87ef7750ef184104",
    "stateView": "0x571291b572ed32ce6751a2cb2486ebee8defb9b4",
    "quoter": "0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba",
    "permit2": "0x000000000022D473030F116dDEE9F6B43aC78BA3"
  },
  "explorers": {
    "basescan": "https://sepolia.basescan.org/"
  }
}
EOF

echo -e "${GREEN}✅ Addresses saved to:${NC} deployments/base-sepolia.json"
echo ""

# Display summary
echo "═══════════════════════════════════════════════════════"
echo "🎉 DEPLOYMENT COMPLETE!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📋 Contract Addresses:"
echo "──────────────────────────────────────────────────────"
echo -e "Market:        ${GREEN}$MARKET${NC}"
echo -e "QUSD:          ${GREEN}$QUSD${NC}"
echo -e "TokenFactory:  ${GREEN}$FACTORY${NC}"
echo -e "Resolver:      ${GREEN}$RESOLVER${NC}"
echo -e "MarketView:    ${GREEN}$VIEW${NC}"
echo ""
echo "🔗 Uniswap v4:"
echo "──────────────────────────────────────────────────────"
echo -e "PoolManager:   $POOL_MANAGER"
echo -e "PositionMgr:   $POSITION_MANAGER"
echo ""
echo "🌐 Explorer:"
echo "──────────────────────────────────────────────────────"
echo "https://sepolia.basescan.org/address/$MARKET"
echo ""
echo "📝 Next Steps:"
echo "──────────────────────────────────────────────────────"
echo "1. Verify contracts on BaseScan (optional)"
echo "2. Update your frontend with the addresses from:"
echo "   deployments/base-sepolia.json"
echo "3. Export ABIs for frontend:"
echo "   forge inspect MarketV2 abi > frontend/abi/MarketV2.json"
echo "   forge inspect MarketView abi > frontend/abi/MarketView.json"
echo "4. Test the deployment:"
echo "   cast call $QUSD \"name()\" --rpc-url \$RPC_URL"
echo ""
echo "═══════════════════════════════════════════════════════"

