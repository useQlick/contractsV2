// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DecisionTokenERC20} from "./DecisionTokenERC20.sol";

/// @title DecisionTokenFactory
/// @notice Factory for creating DecisionTokenERC20 instances
/// @dev Manages deployment of YES/NO tokens for each proposal
contract DecisionTokenFactory {
    /// @notice Market contract that owns tokens
    address public immutable market;

    /// @notice Mapping from proposalId and tokenType to token address
    /// @dev proposalId => isYesToken => token address
    mapping(uint256 => mapping(bool => address)) public tokens;

    /// @notice Emitted when new decision tokens are created
    event TokensCreated(
        uint256 indexed proposalId,
        address indexed yesToken,
        address indexed noToken
    );

    error OnlyMarket();
    error TokensAlreadyExist(uint256 proposalId);

    modifier onlyMarket() {
        if (msg.sender != market) revert OnlyMarket();
        _;
    }

    constructor(address _market) {
        market = _market;
    }

    /// @notice Create YES and NO tokens for a proposal
    /// @param proposalId ID of the proposal
    /// @param proposalDescription Description for token names
    /// @return yesToken Address of YES token
    /// @return noToken Address of NO token
    function createTokens(uint256 proposalId, string memory proposalDescription)
        external
        onlyMarket
        returns (address yesToken, address noToken)
    {
        if (tokens[proposalId][true] != address(0)) {
            revert TokensAlreadyExist(proposalId);
        }

        // Create YES token
        string memory yesName = string.concat("Proposal #", _toString(proposalId), " YES: ", proposalDescription);
        string memory yesSymbol = string.concat("P", _toString(proposalId), "-YES");
        
        DecisionTokenERC20 yes = new DecisionTokenERC20(
            proposalId,
            true,
            yesName,
            yesSymbol,
            market
        );

        // Create NO token
        string memory noName = string.concat("Proposal #", _toString(proposalId), " NO: ", proposalDescription);
        string memory noSymbol = string.concat("P", _toString(proposalId), "-NO");
        
        DecisionTokenERC20 no = new DecisionTokenERC20(
            proposalId,
            false,
            noName,
            noSymbol,
            market
        );

        // Set market as minter
        yes.setMinter(market);
        no.setMinter(market);

        yesToken = address(yes);
        noToken = address(no);

        tokens[proposalId][true] = yesToken;
        tokens[proposalId][false] = noToken;

        emit TokensCreated(proposalId, yesToken, noToken);
    }

    /// @notice Get token addresses for a proposal
    /// @param proposalId ID of the proposal
    /// @return yesToken Address of YES token
    /// @return noToken Address of NO token
    function getTokens(uint256 proposalId)
        external
        view
        returns (address yesToken, address noToken)
    {
        yesToken = tokens[proposalId][true];
        noToken = tokens[proposalId][false];
    }

    /// @notice Simple uint to string conversion
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

