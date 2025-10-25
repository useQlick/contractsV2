// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {MarketV2} from "./MarketV2.sol";
import {MarketConfig, ProposalConfig, MarketStatus} from "./common/MarketData.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MarketView
/// @notice Frontend-friendly view functions for the Market system
/// @dev Aggregates data from multiple sources for easy frontend consumption
contract MarketView {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    MarketV2 public immutable market;
    IPoolManager public immutable poolManager;

    struct MarketInfo {
        uint256 marketId;
        address marketToken;
        uint256 minDeposit;
        uint256 deadline;
        address resolver;
        MarketStatus status;
        uint256 totalDeposits;
        uint256 proposalCount;
        uint256 timeRemaining;
        bool canGraduate;
    }

    struct ProposalInfo {
        uint256 proposalId;
        uint256 marketId;
        address creator;
        string description;
        uint256 depositAmount;
        uint256 createdAt;
        address yesToken;
        address noToken;
        uint256 yesPrice;
        uint256 noPrice;
        uint256 yesLiquidity;
        uint256 noLiquidity;
        bool isAccepted;
    }

    struct UserPosition {
        uint256 marketDeposit;
        uint256 yesBalance;
        uint256 noBalance;
        uint256 qusdBalance;
        uint256 potentialWinnings;
        bool canRedeem;
    }

    constructor(address _market, address _poolManager) {
        market = MarketV2(_market);
        poolManager = IPoolManager(_poolManager);
    }

    /// @notice Get comprehensive market information
    function getMarketInfo(uint256 marketId) external view returns (MarketInfo memory info) {
        MarketConfig memory config = market.getMarket(marketId);

        info = MarketInfo({
            marketId: config.marketId,
            marketToken: config.marketToken,
            minDeposit: config.minDeposit,
            deadline: config.deadline,
            resolver: config.resolver,
            status: config.status,
            totalDeposits: config.totalDeposits,
            proposalCount: config.proposalCount,
            timeRemaining: block.timestamp < config.deadline
                ? config.deadline - block.timestamp
                : 0,
            canGraduate: config.status == MarketStatus.OPEN
                && block.timestamp >= config.deadline
                && config.proposalCount > 0
        });
    }

    /// @notice Get comprehensive proposal information
    function getProposalInfo(uint256 proposalId) external view returns (ProposalInfo memory info) {
        ProposalConfig memory config = market.getProposal(proposalId);
        (address yesToken, address noToken) = market.getTokens(proposalId);
        (uint256 yesPrice, uint256 noPrice) = market.getCurrentPrice(proposalId);

        uint256 acceptedProposal = market.getAcceptedProposal(config.marketId);

        info = ProposalInfo({
            proposalId: config.proposalId,
            marketId: config.marketId,
            creator: config.creator,
            description: config.description,
            depositAmount: config.depositAmount,
            createdAt: config.createdAt,
            yesToken: yesToken,
            noToken: noToken,
            yesPrice: yesPrice,
            noPrice: noPrice,
            yesLiquidity: yesToken != address(0) ? IERC20(yesToken).totalSupply() : 0,
            noLiquidity: noToken != address(0) ? IERC20(noToken).totalSupply() : 0,
            isAccepted: acceptedProposal == proposalId
        });
    }

    /// @notice Get all proposals for a market
    function getMarketProposals(uint256 marketId, uint256 limit, uint256 offset)
        external
        view
        returns (ProposalInfo[] memory proposals)
    {
        MarketConfig memory marketConfig = market.getMarket(marketId);
        uint256 count = marketConfig.proposalCount;

        if (offset >= count) {
            return new ProposalInfo[](0);
        }

        uint256 remaining = count - offset;
        uint256 size = remaining < limit ? remaining : limit;

        proposals = new ProposalInfo[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 proposalId = offset + i + 1;
            ProposalConfig memory config = market.getProposal(proposalId);
            (address yesToken, address noToken) = market.getTokens(proposalId);
            (uint256 yesPrice, uint256 noPrice) = market.getCurrentPrice(proposalId);

            uint256 acceptedProposal = market.getAcceptedProposal(marketId);

            proposals[i] = ProposalInfo({
                proposalId: config.proposalId,
                marketId: config.marketId,
                creator: config.creator,
                description: config.description,
                depositAmount: config.depositAmount,
                createdAt: config.createdAt,
                yesToken: yesToken,
                noToken: noToken,
                yesPrice: yesPrice,
                noPrice: noPrice,
                yesLiquidity: yesToken != address(0) ? IERC20(yesToken).totalSupply() : 0,
                noLiquidity: noToken != address(0) ? IERC20(noToken).totalSupply() : 0,
                isAccepted: acceptedProposal == proposalId
            });
        }
    }

    /// @notice Get user's position in a proposal
    function getUserPosition(uint256 proposalId, uint256 marketId, address user)
        external
        view
        returns (UserPosition memory position)
    {
        MarketConfig memory marketConfig = market.getMarket(marketId);
        (address yesToken, address noToken) = market.getTokens(proposalId);

        uint256 yesBalance = yesToken != address(0) ? IERC20(yesToken).balanceOf(user) : 0;
        uint256 noBalance = noToken != address(0) ? IERC20(noToken).balanceOf(user) : 0;
        uint256 qusdBalance = IERC20(address(market.qusd())).balanceOf(user);

        bool canRedeem = (marketConfig.status == MarketStatus.RESOLVED_YES
            || marketConfig.status == MarketStatus.RESOLVED_NO)
            && (yesBalance > 0 || noBalance > 0 || qusdBalance > 0);

        uint256 potentialWinnings = 0;
        if (marketConfig.status == MarketStatus.RESOLVED_YES) {
            potentialWinnings = yesBalance + qusdBalance;
        } else if (marketConfig.status == MarketStatus.RESOLVED_NO) {
            potentialWinnings = noBalance + qusdBalance;
        }

        position = UserPosition({
            marketDeposit: market.getDeposit(marketId, user),
            yesBalance: yesBalance,
            noBalance: noBalance,
            qusdBalance: qusdBalance,
            potentialWinnings: potentialWinnings,
            canRedeem: canRedeem
        });
    }

    /// @notice Get all active markets
    function getActiveMarkets(uint256 limit, uint256 offset)
        external
        view
        returns (MarketInfo[] memory markets)
    {
        // Note: This is a simplified version
        // In production, you'd track market IDs in an array
        // For now, return empty array
        return new MarketInfo[](0);
    }

    /// @notice Calculate expected output for a swap
    /// @dev This is a view function that doesn't execute the swap
    function quoteSwap(
        uint256 proposalId,
        bool buyYes,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        // Simplified quote calculation
        // In production, use Quoter contract from Uniswap v4
        (uint256 yesPrice, uint256 noPrice) = market.getCurrentPrice(proposalId);

        if (buyYes) {
            amountOut = (amountIn * 1e18) / yesPrice;
        } else {
            amountOut = (amountIn * 1e18) / noPrice;
        }

        // Apply slippage (simplified)
        amountOut = (amountOut * 97) / 100; // 3% slippage
    }

    /// @notice Get leaderboard of proposals by YES price
    function getLeaderboard(uint256 marketId, uint256 limit)
        external
        view
        returns (ProposalInfo[] memory topProposals)
    {
        MarketConfig memory marketConfig = market.getMarket(marketId);
        uint256 count = marketConfig.proposalCount;

        if (count == 0) {
            return new ProposalInfo[](0);
        }

        uint256 size = count < limit ? count : limit;

        // Simple implementation - in production, maintain sorted list
        topProposals = new ProposalInfo[](size);

        for (uint256 i = 0; i < size && i < count; i++) {
            uint256 proposalId = i + 1;
            ProposalConfig memory config = market.getProposal(proposalId);
            (address yesToken, address noToken) = market.getTokens(proposalId);
            (uint256 yesPrice, uint256 noPrice) = market.getCurrentPrice(proposalId);

            uint256 acceptedProposal = market.getAcceptedProposal(marketId);

            topProposals[i] = ProposalInfo({
                proposalId: config.proposalId,
                marketId: config.marketId,
                creator: config.creator,
                description: config.description,
                depositAmount: config.depositAmount,
                createdAt: config.createdAt,
                yesToken: yesToken,
                noToken: noToken,
                yesPrice: yesPrice,
                noPrice: noPrice,
                yesLiquidity: yesToken != address(0) ? IERC20(yesToken).totalSupply() : 0,
                noLiquidity: noToken != address(0) ? IERC20(noToken).totalSupply() : 0,
                isAccepted: acceptedProposal == proposalId
            });
        }
    }
}

