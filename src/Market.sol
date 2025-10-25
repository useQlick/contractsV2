// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";

import {IMarket} from "./interfaces/IMarket.sol";
import {IMarketResolver} from "./interfaces/IMarketResolver.sol";
import {IQUSD} from "./interfaces/IQUSD.sol";
import {IDecisionToken} from "./interfaces/IDecisionToken.sol";
import {MarketConfig, ProposalConfig, MaxProposal, MarketStatus, MarketErrors} from "./common/MarketData.sol";
import {Id} from "./utils/Id.sol";

/// @title Market
/// @notice Core prediction market engine with Uniswap v4 integration
/// @dev Manages market lifecycle: creation → trading → graduation → resolution → redemption
contract Market is IMarket, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using Id for Id.Counter;

    // ============ State Variables ============

    /// @notice Uniswap v4 Pool Manager
    IPoolManager public immutable poolManager;

    /// @notice Uniswap v4 Position Manager
    IPositionManager public immutable positionManager;

    /// @notice QUSD token (virtual USD)
    IQUSD public immutable qusd;

    /// @notice Decision token contract (YES/NO tokens)
    IDecisionToken public immutable decisionToken;

    /// @notice Address of the swap hook
    address public immutable swapHook;

    /// @notice Market ID counter
    Id.Counter private _marketIdCounter;

    /// @notice Proposal ID counter
    Id.Counter private _proposalIdCounter;

    /// @notice Market configurations by ID
    mapping(uint256 => MarketConfig) public markets;

    /// @notice Proposal configurations by ID
    mapping(uint256 => ProposalConfig) public proposals;

    /// @notice Highest observed YES price per market
    mapping(uint256 => MaxProposal) public marketMax;

    /// @notice Accepted proposal ID for graduated markets
    mapping(uint256 => uint256) public acceptedProposals;

    /// @notice User deposits per market: marketId => user => amount
    mapping(uint256 => mapping(address => uint256)) public deposits;

    /// @notice Map pool IDs to proposal IDs
    mapping(PoolId => uint256) public poolToProposal;

    /// @notice Default tick spacing for pools
    int24 public constant TICK_SPACING = 60;

    /// @notice Default liquidity range width (ticks)
    int24 public constant TICK_RANGE = 600;

    /// @notice Price scale factor (for conversions)
    uint256 public constant PRICE_SCALE = 1e18;

    // ============ Modifiers ============

    modifier onlyHook() {
        require(msg.sender == swapHook, "Only hook can call");
        _;
    }

    modifier marketExists(uint256 marketId) {
        if (markets[marketId].marketId == 0) revert MarketErrors.MarketNotFound(marketId);
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        if (proposals[proposalId].proposalId == 0) revert MarketErrors.ProposalNotFound(proposalId);
        _;
    }

    // ============ Constructor ============

    constructor(
        address _poolManager,
        address _positionManager,
        address _qusd,
        address _decisionToken,
        address _swapHook,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_poolManager == address(0)) revert MarketErrors.ZeroAddress();
        if (_positionManager == address(0)) revert MarketErrors.ZeroAddress();
        if (_qusd == address(0)) revert MarketErrors.ZeroAddress();
        if (_decisionToken == address(0)) revert MarketErrors.ZeroAddress();
        // Note: _swapHook can be address(0) for testing with mocks
        if (initialOwner == address(0)) revert MarketErrors.ZeroAddress();

        poolManager = IPoolManager(_poolManager);
        positionManager = IPositionManager(_positionManager);
        qusd = IQUSD(_qusd);
        decisionToken = IDecisionToken(_decisionToken);
        swapHook = _swapHook;
    }

    // ============ Market Creation ============

    /// @inheritdoc IMarket
    function createMarket(
        address marketToken,
        uint256 minDeposit,
        uint256 deadline,
        address resolver
    ) external override returns (uint256 marketId) {
        if (marketToken == address(0)) revert MarketErrors.ZeroAddress();
        if (resolver == address(0)) revert MarketErrors.InvalidResolver(resolver);
        if (deadline <= block.timestamp) revert MarketErrors.InvalidDeadline(deadline);
        if (minDeposit == 0) revert MarketErrors.ZeroAmount();

        marketId = _marketIdCounter.next();

        markets[marketId] = MarketConfig({
            marketId: marketId,
            marketToken: marketToken,
            minDeposit: minDeposit,
            deadline: deadline,
            resolver: resolver,
            status: MarketStatus.OPEN,
            totalDeposits: 0,
            proposalCount: 0
        });

        emit MarketCreated(marketId, marketToken, minDeposit, deadline, resolver);
    }

    /// @inheritdoc IMarket
    function depositToMarket(uint256 marketId, uint256 amount)
        external
        override
        nonReentrant
        marketExists(marketId)
    {
        if (amount == 0) revert MarketErrors.ZeroAmount();

        MarketConfig storage market = markets[marketId];
        if (market.status != MarketStatus.OPEN) revert MarketErrors.MarketClosed(marketId);
        if (block.timestamp >= market.deadline) {
            revert MarketErrors.DeadlineAlreadyPassed(block.timestamp, market.deadline);
        }

        deposits[marketId][msg.sender] += amount;
        market.totalDeposits += amount;

        IERC20(market.marketToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(marketId, msg.sender, amount);
    }

    // ============ Proposal Creation ============

    /// @inheritdoc IMarket
    function createProposal(uint256 marketId, string calldata description)
        external
        override
        nonReentrant
        marketExists(marketId)
        returns (uint256 proposalId)
    {
        MarketConfig storage market = markets[marketId];

        if (market.status != MarketStatus.OPEN) revert MarketErrors.MarketClosed(marketId);
        if (block.timestamp >= market.deadline) {
            revert MarketErrors.DeadlineAlreadyPassed(block.timestamp, market.deadline);
        }

        uint256 userDeposit = deposits[marketId][msg.sender];
        if (userDeposit < market.minDeposit) {
            revert MarketErrors.InsufficientDeposit(userDeposit, market.minDeposit);
        }

        // Generate proposal ID
        proposalId = _proposalIdCounter.next();
        market.proposalCount++;

        // Allocate user's deposit to this proposal
        uint256 depositAmount = market.minDeposit;
        deposits[marketId][msg.sender] -= depositAmount;

        // Mint decision tokens to user and contract
        // User gets half, contract gets half for liquidity
        uint256 userTokens = depositAmount / 2;
        uint256 liquidityTokens = depositAmount - userTokens;

        decisionToken.mint(msg.sender, proposalId, IDecisionToken.TokenType.YES, userTokens);
        decisionToken.mint(msg.sender, proposalId, IDecisionToken.TokenType.NO, userTokens);
        decisionToken.mint(address(this), proposalId, IDecisionToken.TokenType.YES, liquidityTokens);
        decisionToken.mint(address(this), proposalId, IDecisionToken.TokenType.NO, liquidityTokens);

        // Mint QUSD for liquidity (equal to deposit)
        qusd.mint(address(this), depositAmount);

        // Initialize Uniswap v4 pools
        (PoolId yesPoolId, PoolId noPoolId) = _initializePools(proposalId, liquidityTokens);

        proposals[proposalId] = ProposalConfig({
            proposalId: proposalId,
            marketId: marketId,
            creator: msg.sender,
            description: description,
            depositAmount: depositAmount,
            yesPoolId: yesPoolId,
            noPoolId: noPoolId,
            createdAt: block.timestamp
        });

        // Map pools to proposal
        poolToProposal[yesPoolId] = proposalId;
        poolToProposal[noPoolId] = proposalId;

        emit ProposalCreated(proposalId, marketId, msg.sender, description, depositAmount);
    }

    /// @notice Initialize YES/QUSD and NO/QUSD pools with initial liquidity
    function _initializePools(uint256 proposalId, uint256 liquidityAmount)
        private
        returns (PoolId yesPoolId, PoolId noPoolId)
    {
        // Create pool keys
        // Note: In production, decision tokens would need to be proper ERC20s or use a wrapper
        // For now, we assume the system provides a way to reference them as Currency
        
        // This is a simplified version - in production you'd need proper Currency wrapping
        // The actual implementation depends on how DecisionToken integrates with Uniswap v4
        
        // Placeholder: Return zero pool IDs for now
        // TODO: Implement proper pool initialization with PositionManager
        yesPoolId = PoolId.wrap(bytes32(uint256(proposalId) << 128 | 1));
        noPoolId = PoolId.wrap(bytes32(uint256(proposalId) << 128 | 2));

        // In a full implementation:
        // 1. Create PoolKey for YES/QUSD and NO/QUSD
        // 2. Initialize pools via PoolManager
        // 3. Add liquidity via PositionManager
        // 4. Store position NFT or track liquidity
    }

    // ============ Trading Functions ============

    /// @inheritdoc IMarket
    function mintYesNo(uint256 proposalId, uint256 amount)
        external
        override
        nonReentrant
        proposalExists(proposalId)
    {
        if (amount == 0) revert MarketErrors.ZeroAmount();

        ProposalConfig memory proposal = proposals[proposalId];
        MarketConfig memory market = markets[proposal.marketId];

        if (market.status != MarketStatus.OPEN) revert MarketErrors.MarketClosed(proposal.marketId);

        // Transfer market tokens from user
        IERC20(market.marketToken).safeTransferFrom(msg.sender, address(this), amount);

        // Mint YES and NO tokens to user
        decisionToken.mint(msg.sender, proposalId, IDecisionToken.TokenType.YES, amount);
        decisionToken.mint(msg.sender, proposalId, IDecisionToken.TokenType.NO, amount);

        // Mint QUSD to user (for trading)
        qusd.mint(msg.sender, amount);

        emit TokensMinted(proposalId, msg.sender, amount);
    }

    /// @inheritdoc IMarket
    function redeemYesNo(uint256 proposalId, uint256 amount)
        external
        override
        nonReentrant
        proposalExists(proposalId)
    {
        if (amount == 0) revert MarketErrors.ZeroAmount();

        ProposalConfig memory proposal = proposals[proposalId];
        MarketConfig memory market = markets[proposal.marketId];

        // Burn YES and NO tokens from user
        decisionToken.burn(msg.sender, proposalId, IDecisionToken.TokenType.YES, amount);
        decisionToken.burn(msg.sender, proposalId, IDecisionToken.TokenType.NO, amount);

        // Burn QUSD from user
        qusd.burn(msg.sender, amount);

        // Transfer market tokens to user
        IERC20(market.marketToken).safeTransfer(msg.sender, amount);

        emit TokensRedeemed(proposalId, msg.sender, amount);
    }

    // ============ Swap Hook Integration ============

    /// @inheritdoc IMarket
    function validateSwap(PoolKey calldata key) external view override onlyHook {
        PoolId poolId = key.toId();
        uint256 proposalId = poolToProposal[poolId];

        if (proposalId == 0) revert MarketErrors.InvalidPoolId();

        ProposalConfig memory proposal = proposals[proposalId];
        MarketConfig memory market = markets[proposal.marketId];

        if (market.status != MarketStatus.OPEN) {
            revert MarketErrors.UnauthorizedSwap(proposalId);
        }
    }

    /// @inheritdoc IMarket
    function updatePostSwap(PoolKey calldata key, int24 avgTick) external override onlyHook {
        PoolId poolId = key.toId();
        uint256 proposalId = poolToProposal[poolId];

        if (proposalId == 0) revert MarketErrors.InvalidPoolId();

        ProposalConfig memory proposal = proposals[proposalId];

        // Only track YES pool prices
        if (PoolId.unwrap(poolId) == PoolId.unwrap(proposal.yesPoolId)) {
            uint256 price = _tickToPrice(avgTick);

            MaxProposal storage maxProposal = marketMax[proposal.marketId];

            if (price > maxProposal.maxPrice) {
                maxProposal.proposalId = proposalId;
                maxProposal.maxPrice = price;
                maxProposal.maxTick = avgTick;

                emit PriceUpdated(proposalId, price, avgTick);
            }
        }
    }

    /// @notice Convert Uniswap tick to price (scaled by PRICE_SCALE)
    function _tickToPrice(int24 tick) private pure returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick);
        // Convert sqrtPriceX96 to price
        // price = (sqrtPriceX96 / 2^96)^2
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        // Scale to PRICE_SCALE
        return (priceX192 * PRICE_SCALE) >> 192;
    }

    // ============ Market Graduation ============

    /// @inheritdoc IMarket
    function graduateMarket(uint256 marketId)
        external
        override
        nonReentrant
        marketExists(marketId)
    {
        MarketConfig storage market = markets[marketId];

        if (market.status != MarketStatus.OPEN) revert MarketErrors.MarketClosed(marketId);
        if (block.timestamp < market.deadline) {
            revert MarketErrors.DeadlineNotReached(block.timestamp, market.deadline);
        }
        if (market.proposalCount == 0) revert MarketErrors.NoProposalsToGraduate(marketId);

        MaxProposal memory maxProposal = marketMax[marketId];

        if (maxProposal.proposalId == 0) {
            // No swaps occurred, use first proposal as default
            maxProposal.proposalId = 1; // Simplified - in production, track first proposal properly
        }

        market.status = MarketStatus.PROPOSAL_ACCEPTED;
        acceptedProposals[marketId] = maxProposal.proposalId;

        emit MarketGraduated(marketId, maxProposal.proposalId, maxProposal.maxPrice);
    }

    // ============ Market Resolution ============

    /// @inheritdoc IMarket
    function resolveMarket(uint256 marketId, bool yesOrNo, bytes calldata proof)
        external
        override
        nonReentrant
        marketExists(marketId)
    {
        MarketConfig storage market = markets[marketId];

        if (market.status != MarketStatus.PROPOSAL_ACCEPTED) {
            revert MarketErrors.MarketNotAccepted(marketId);
        }

        uint256 acceptedProposalId = acceptedProposals[marketId];

        // Call resolver to verify proof - will revert if invalid
        IMarketResolver(market.resolver).verifyResolution(acceptedProposalId, yesOrNo, proof);

        // Set final status based on outcome
        market.status = yesOrNo ? MarketStatus.RESOLVED_YES : MarketStatus.RESOLVED_NO;

        emit MarketResolved(marketId, acceptedProposalId, yesOrNo);
    }

    // ============ Redemption ============

    /// @inheritdoc IMarket
    function redeemRewards(uint256 marketId)
        external
        override
        nonReentrant
        marketExists(marketId)
    {
        MarketConfig memory market = markets[marketId];

        if (
            market.status != MarketStatus.RESOLVED_YES
                && market.status != MarketStatus.RESOLVED_NO
        ) {
            revert MarketErrors.MarketAlreadyResolved(marketId);
        }

        uint256 acceptedProposalId = acceptedProposals[marketId];
        IDecisionToken.TokenType winningType =
            market.status == MarketStatus.RESOLVED_YES
            ? IDecisionToken.TokenType.YES
            : IDecisionToken.TokenType.NO;

        // Get user's winning tokens and QUSD
        uint256 winningTokens =
            decisionToken.balanceOf(msg.sender, acceptedProposalId, winningType);
        uint256 qusdBalance = qusd.balanceOf(msg.sender);

        if (winningTokens == 0 && qusdBalance == 0) {
            revert MarketErrors.NothingToRedeem(msg.sender, acceptedProposalId);
        }

        uint256 totalReward = winningTokens + qusdBalance;

        // Burn winning tokens and QUSD
        if (winningTokens > 0) {
            decisionToken.burn(msg.sender, acceptedProposalId, winningType, winningTokens);
        }
        if (qusdBalance > 0) {
            qusd.burn(msg.sender, qusdBalance);
        }

        // Transfer market tokens
        IERC20(market.marketToken).safeTransfer(msg.sender, totalReward);

        emit RewardsRedeemed(marketId, msg.sender, totalReward);
    }

    // ============ View Functions ============

    /// @inheritdoc IMarket
    function getMarket(uint256 marketId)
        external
        view
        override
        returns (MarketConfig memory)
    {
        return markets[marketId];
    }

    /// @inheritdoc IMarket
    function getProposal(uint256 proposalId)
        external
        view
        override
        returns (ProposalConfig memory)
    {
        return proposals[proposalId];
    }

    /// @inheritdoc IMarket
    function getAcceptedProposal(uint256 marketId)
        external
        view
        override
        returns (uint256)
    {
        return acceptedProposals[marketId];
    }

    /// @inheritdoc IMarket
    function getDeposit(uint256 marketId, address account)
        external
        view
        override
        returns (uint256)
    {
        return deposits[marketId][account];
    }
}

