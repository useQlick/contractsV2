// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IMarketResolver
/// @notice Interface for oracle resolvers that verify real-world outcomes
/// @dev Resolvers must revert if the proof is invalid. Market.sol relies on this behavior.
interface IMarketResolver {
    /// @notice Verify a resolution proof for a proposal
    /// @param proposalId ID of the proposal being resolved
    /// @param yesOrNo The claimed outcome (true = YES wins, false = NO wins)
    /// @param proof Arbitrary proof data (signature, oracle data, etc.)
    /// @dev MUST revert if proof is invalid or doesn't match the claimed outcome
    /// @dev If this function returns successfully, Market.sol will finalize the outcome
    function verifyResolution(uint256 proposalId, bool yesOrNo, bytes calldata proof) external;

    /// @notice Event emitted when a proposal outcome is verified
    event ResolutionVerified(uint256 indexed proposalId, bool yesOrNo, bytes proof);
}

