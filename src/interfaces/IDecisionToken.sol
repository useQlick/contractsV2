// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IDecisionToken
/// @notice Interface for DecisionToken - represents YES/NO positions in proposals
interface IDecisionToken {
    enum TokenType {
        YES,
        NO
    }

    /// @notice Get the balance of a specific token type for an account
    /// @param account Address to check balance for
    /// @param proposalId ID of the proposal
    /// @param tokenType Type of token (YES or NO)
    /// @return Balance of the specified token type
    function balanceOf(address account, uint256 proposalId, TokenType tokenType) external view returns (uint256);

    /// @notice Mint decision tokens to a recipient
    /// @param to Address to receive the minted tokens
    /// @param proposalId ID of the proposal
    /// @param tokenType Type of token (YES or NO)
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 proposalId, TokenType tokenType, uint256 amount) external;

    /// @notice Burn decision tokens from a holder
    /// @param from Address to burn tokens from
    /// @param proposalId ID of the proposal
    /// @param tokenType Type of token (YES or NO)
    /// @param amount Amount of tokens to burn
    function burn(address from, uint256 proposalId, TokenType tokenType, uint256 amount) external;

    /// @notice Transfer decision tokens between accounts
    /// @param from Address to transfer from
    /// @param to Address to transfer to
    /// @param proposalId ID of the proposal
    /// @param tokenType Type of token (YES or NO)
    /// @param amount Amount of tokens to transfer
    function transfer(address from, address to, uint256 proposalId, TokenType tokenType, uint256 amount) external;
}

