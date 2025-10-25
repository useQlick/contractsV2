// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMarketResolver} from "../interfaces/IMarketResolver.sol";

/// @title SimpleResolver
/// @notice Centralized resolver for development and testing
/// @dev WARNING: This is a centralized resolver. For production, use decentralized oracles
/// @dev Owner can set outcomes directly. Use only in trusted environments or for testing.
contract SimpleResolver is IMarketResolver, Ownable {
    /// @notice Stored outcomes: proposalId => outcome (true = YES, false = NO)
    mapping(uint256 => bool) public outcomes;

    /// @notice Whether an outcome has been set for a proposal
    mapping(uint256 => bool) public outcomeSet;

    /// @notice Emitted when owner sets an outcome
    event OutcomeSet(uint256 indexed proposalId, bool yesOrNo);

    error OutcomeNotSet(uint256 proposalId);
    error OutcomeMismatch(uint256 proposalId, bool expected, bool provided);
    error OutcomeAlreadySet(uint256 proposalId);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Owner sets the verified outcome for a proposal
    /// @param proposalId ID of the proposal
    /// @param yesOrNo The verified outcome (true = YES wins, false = NO wins)
    function setOutcome(uint256 proposalId, bool yesOrNo) external onlyOwner {
        if (outcomeSet[proposalId]) revert OutcomeAlreadySet(proposalId);

        outcomes[proposalId] = yesOrNo;
        outcomeSet[proposalId] = true;

        emit OutcomeSet(proposalId, yesOrNo);
    }

    /// @notice Force update an outcome (admin override)
    /// @param proposalId ID of the proposal
    /// @param yesOrNo The new verified outcome
    function updateOutcome(uint256 proposalId, bool yesOrNo) external onlyOwner {
        outcomes[proposalId] = yesOrNo;
        outcomeSet[proposalId] = true;

        emit OutcomeSet(proposalId, yesOrNo);
    }

    /// @inheritdoc IMarketResolver
    function verifyResolution(uint256 proposalId, bool yesOrNo, bytes calldata)
        external
        override
    {
        // Check if outcome has been set
        if (!outcomeSet[proposalId]) {
            revert OutcomeNotSet(proposalId);
        }

        // Verify claimed outcome matches stored outcome
        bool storedOutcome = outcomes[proposalId];
        if (storedOutcome != yesOrNo) {
            revert OutcomeMismatch(proposalId, storedOutcome, yesOrNo);
        }

        // If we reach here, verification passed
        // Emit event for transparency
        emit ResolutionVerified(proposalId, yesOrNo, "");
    }

    /// @notice Get the outcome for a proposal
    /// @param proposalId ID of the proposal
    /// @return yesOrNo The outcome (if set)
    /// @return isSet Whether the outcome has been set
    function getOutcome(uint256 proposalId) external view returns (bool yesOrNo, bool isSet) {
        return (outcomes[proposalId], outcomeSet[proposalId]);
    }
}

