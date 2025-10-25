// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @title MarketData
/// @notice Common data structures and enums used across the market system

/// @notice Status of a market throughout its lifecycle
enum MarketStatus {
    OPEN,              // Market is active, proposals can be created, trading is allowed
    PROPOSAL_ACCEPTED, // Deadline passed, highest YES-priced proposal selected (graduated)
    RESOLVED_YES,      // Oracle verified: accepted proposal outcome is YES
    RESOLVED_NO        // Oracle verified: accepted proposal outcome is NO
}

/// @notice Configuration and state for a market
struct MarketConfig {
    uint256 marketId;           // Unique market identifier
    address marketToken;        // ERC20 token used for deposits (e.g., USDC, DAI)
    uint256 minDeposit;         // Minimum deposit required to create a proposal
    uint256 deadline;           // Timestamp when market closes and graduation occurs
    address resolver;           // Address of the IMarketResolver contract
    MarketStatus status;        // Current lifecycle status
    uint256 totalDeposits;      // Total amount of market tokens deposited
    uint256 proposalCount;      // Number of proposals created for this market
}

/// @notice Configuration and state for a proposal
struct ProposalConfig {
    uint256 proposalId;         // Unique proposal identifier
    uint256 marketId;           // Parent market identifier
    address creator;            // Address that created the proposal
    string description;         // Human-readable proposal description
    uint256 depositAmount;      // Amount of market tokens deposited by creator
    PoolId yesPoolId;           // Uniswap v4 pool ID for YES/QUSD pair
    PoolId noPoolId;            // Uniswap v4 pool ID for NO/QUSD pair
    uint256 createdAt;          // Timestamp of proposal creation
}

/// @notice Tracks the highest observed YES price for a proposal
struct MaxProposal {
    uint256 proposalId;         // Proposal with highest YES price
    uint256 maxPrice;           // Highest observed YES token price (scaled by 1e18)
    int24 maxTick;              // Uniswap tick corresponding to maxPrice
}

/// @title MarketErrors
/// @notice Custom errors for gas-efficient error handling
library MarketErrors {
    error MarketNotFound(uint256 marketId);
    error MarketClosed(uint256 marketId);
    error MarketNotAccepted(uint256 marketId);
    error MarketAlreadyResolved(uint256 marketId);
    error ProposalNotFound(uint256 proposalId);
    error InsufficientDeposit(uint256 provided, uint256 required);
    error DeadlineNotReached(uint256 currentTime, uint256 deadline);
    error DeadlineAlreadyPassed(uint256 currentTime, uint256 deadline);
    error InvalidResolver(address resolver);
    error InvalidPoolId();
    error UnauthorizedSwap(uint256 proposalId);
    error NoProposalsToGraduate(uint256 marketId);
    error NothingToRedeem(address account, uint256 proposalId);
    error TransferFailed(address token, address from, address to, uint256 amount);
    error InvalidTokenType();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidDeadline(uint256 deadline);
}

