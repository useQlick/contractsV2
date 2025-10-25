// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDecisionToken} from "../interfaces/IDecisionToken.sol";

/// @title DecisionToken
/// @notice Represents YES/NO positions in prediction market proposals
/// @dev Uses a multi-dimensional mapping structure: account => proposalId => tokenType => balance
/// @dev Only the Market contract can mint/burn tokens
contract DecisionToken is IDecisionToken, Ownable, ReentrancyGuard {
    /// @notice Token balances: account => proposalId => tokenType => amount
    mapping(address => mapping(uint256 => mapping(TokenType => uint256))) private _balances;

    /// @notice Address authorized to mint and burn tokens (typically the Market contract)
    address public minter;

    /// @notice Emitted when tokens are transferred
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed proposalId,
        TokenType tokenType,
        uint256 amount
    );

    /// @notice Emitted when tokens are minted
    event Mint(address indexed to, uint256 indexed proposalId, TokenType tokenType, uint256 amount);

    /// @notice Emitted when tokens are burned
    event Burn(address indexed from, uint256 indexed proposalId, TokenType tokenType, uint256 amount);

    /// @notice Emitted when the minter address is updated
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    error UnauthorizedMinter(address caller);
    error InsufficientBalance(address account, uint256 proposalId, TokenType tokenType, uint256 balance, uint256 required);
    error ZeroAddress();
    error ZeroAmount();

    modifier onlyMinter() {
        if (msg.sender != minter) revert UnauthorizedMinter(msg.sender);
        _;
    }

    /// @param initialOwner Address that will own this contract (can set minter)
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    /// @notice Set the authorized minter address
    /// @param _minter Address of the Market contract
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();
        address oldMinter = minter;
        minter = _minter;
        emit MinterUpdated(oldMinter, _minter);
    }

    /// @inheritdoc IDecisionToken
    function balanceOf(address account, uint256 proposalId, TokenType tokenType)
        external
        view
        returns (uint256)
    {
        return _balances[account][proposalId][tokenType];
    }

    /// @inheritdoc IDecisionToken
    function mint(address to, uint256 proposalId, TokenType tokenType, uint256 amount)
        external
        onlyMinter
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _balances[to][proposalId][tokenType] += amount;
        emit Mint(to, proposalId, tokenType, amount);
    }

    /// @inheritdoc IDecisionToken
    function burn(address from, uint256 proposalId, TokenType tokenType, uint256 amount)
        external
        onlyMinter
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        uint256 balance = _balances[from][proposalId][tokenType];
        if (balance < amount) {
            revert InsufficientBalance(from, proposalId, tokenType, balance, amount);
        }

        unchecked {
            _balances[from][proposalId][tokenType] = balance - amount;
        }
        emit Burn(from, proposalId, tokenType, amount);
    }

    /// @inheritdoc IDecisionToken
    function transfer(address from, address to, uint256 proposalId, TokenType tokenType, uint256 amount)
        external
        onlyMinter
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 balance = _balances[from][proposalId][tokenType];
        if (balance < amount) {
            revert InsufficientBalance(from, proposalId, tokenType, balance, amount);
        }

        unchecked {
            _balances[from][proposalId][tokenType] = balance - amount;
        }
        _balances[to][proposalId][tokenType] += amount;

        emit Transfer(from, to, proposalId, tokenType, amount);
    }
}

