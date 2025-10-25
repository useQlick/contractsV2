// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MarketConfig, ProposalConfig, MarketStatus} from "../common/MarketData.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @title IMarket
/// @notice Interface for the core Market contract
interface IMarket {
    /// @notice Create a new prediction market
    /// @param marketToken ERC20 token used for deposits
    /// @param minDeposit Minimum deposit required to create proposals
    /// @param deadline Market closing timestamp
    /// @param resolver Address of the IMarketResolver contract
    /// @return marketId Unique identifier for the created market
    function createMarket(
        address marketToken,
        uint256 minDeposit,
        uint256 deadline,
        address resolver
    ) external returns (uint256 marketId);

    /// @notice Deposit market tokens to participate in a market
    /// @param marketId ID of the market to deposit into
    /// @param amount Amount of market tokens to deposit
    function depositToMarket(uint256 marketId, uint256 amount) external;

    /// @notice Create a new proposal within a market
    /// @param marketId ID of the parent market
    /// @param description Human-readable proposal description
    /// @return proposalId Unique identifier for the created proposal
    function createProposal(uint256 marketId, string calldata description)
        external
        returns (uint256 proposalId);

    /// @notice Mint YES and NO tokens by depositing market tokens
    /// @param proposalId ID of the proposal
    /// @param amount Amount of YES/NO token pairs to mint
    function mintYesNo(uint256 proposalId, uint256 amount) external;

    /// @notice Redeem YES and NO token pairs back to market tokens
    /// @param proposalId ID of the proposal
    /// @param amount Amount of YES/NO token pairs to redeem
    function redeemYesNo(uint256 proposalId, uint256 amount) external;

    /// @notice Validate a swap before it occurs (called by hook)
    /// @param key Pool key for the swap
    function validateSwap(PoolKey calldata key) external view;

    /// @notice Update state after a swap (called by hook)
    /// @param key Pool key for the swap
    /// @param avgTick Average tick from the swap
    function updatePostSwap(PoolKey calldata key, int24 avgTick) external;

    /// @notice Graduate the market by selecting the highest YES-priced proposal
    /// @param marketId ID of the market to graduate
    function graduateMarket(uint256 marketId) external;

    /// @notice Resolve a market using oracle verification
    /// @param marketId ID of the market to resolve
    /// @param yesOrNo Claimed outcome (true = YES, false = NO)
    /// @param proof Verification proof for the resolver
    function resolveMarket(uint256 marketId, bool yesOrNo, bytes calldata proof) external;

    /// @notice Redeem rewards after market resolution
    /// @param marketId ID of the resolved market
    function redeemRewards(uint256 marketId) external;

    /// @notice Get market configuration
    /// @param marketId ID of the market
    /// @return Market configuration struct
    function getMarket(uint256 marketId) external view returns (MarketConfig memory);

    /// @notice Get proposal configuration
    /// @param proposalId ID of the proposal
    /// @return Proposal configuration struct
    function getProposal(uint256 proposalId) external view returns (ProposalConfig memory);

    /// @notice Get the accepted proposal for a graduated market
    /// @param marketId ID of the market
    /// @return proposalId ID of the accepted proposal
    function getAcceptedProposal(uint256 marketId) external view returns (uint256 proposalId);

    /// @notice Get user's deposit balance in a market
    /// @param marketId ID of the market
    /// @param account User's address
    /// @return Deposit amount
    function getDeposit(uint256 marketId, address account) external view returns (uint256);

    // Events
    event MarketCreated(
        uint256 indexed marketId,
        address indexed marketToken,
        uint256 minDeposit,
        uint256 deadline,
        address resolver
    );

    event Deposited(uint256 indexed marketId, address indexed account, uint256 amount);

    event ProposalCreated(
        uint256 indexed proposalId,
        uint256 indexed marketId,
        address indexed creator,
        string description,
        uint256 depositAmount
    );

    event TokensMinted(uint256 indexed proposalId, address indexed account, uint256 amount);

    event TokensRedeemed(uint256 indexed proposalId, address indexed account, uint256 amount);

    event PriceUpdated(uint256 indexed proposalId, uint256 price, int24 tick);

    event MarketGraduated(uint256 indexed marketId, uint256 indexed acceptedProposalId, uint256 maxPrice);

    event MarketResolved(uint256 indexed marketId, uint256 indexed acceptedProposalId, bool yesOrNo);

    event RewardsRedeemed(uint256 indexed marketId, address indexed account, uint256 amount);
}

