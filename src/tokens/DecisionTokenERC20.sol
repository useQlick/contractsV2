// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DecisionTokenERC20
/// @notice ERC20 wrapper for individual DecisionToken instances (YES or NO for a specific proposal)
/// @dev This makes DecisionTokens compatible with Uniswap v4 Currency
contract DecisionTokenERC20 is ERC20, Ownable {
    /// @notice The proposal this token represents
    uint256 public immutable proposalId;

    /// @notice Whether this is a YES (true) or NO (false) token
    bool public immutable isYesToken;

    /// @notice Address authorized to mint and burn (typically the Market contract)
    address public minter;

    /// @notice Emitted when the minter is updated
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    error UnauthorizedMinter(address caller);
    error ZeroAddress();

    modifier onlyMinter() {
        if (msg.sender != minter) revert UnauthorizedMinter(msg.sender);
        _;
    }

    /// @param _proposalId ID of the proposal this token represents
    /// @param _isYesToken true for YES token, false for NO token
    /// @param _name Token name (e.g., "Proposal #1 YES")
    /// @param _symbol Token symbol (e.g., "P1-YES")
    /// @param initialOwner Initial owner who can set minter
    constructor(
        uint256 _proposalId,
        bool _isYesToken,
        string memory _name,
        string memory _symbol,
        address initialOwner
    ) ERC20(_name, _symbol) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        proposalId = _proposalId;
        isYesToken = _isYesToken;
    }

    /// @notice Set the authorized minter
    /// @param _minter Address that can mint/burn tokens
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();
        address oldMinter = minter;
        minter = _minter;
        emit MinterUpdated(oldMinter, _minter);
    }

    /// @notice Mint tokens to an address
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0)) revert ZeroAddress();
        _mint(to, amount);
    }

    /// @notice Burn tokens from an address
    /// @param from Address to burn from
    /// @param amount Amount to burn
    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}

