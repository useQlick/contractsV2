// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IQUSD
/// @notice Interface for QUSD (Qlick USD) - the virtual USD token used for liquidity and trading
interface IQUSD is IERC20 {
    /// @notice Mint QUSD tokens to a recipient
    /// @param to Address to receive the minted tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burn QUSD tokens from a holder
    /// @param from Address to burn tokens from
    /// @param amount Amount of tokens to burn
    function burn(address from, uint256 amount) external;
}

