// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Id
/// @notice Simple counter-based ID generator for markets and proposals
/// @dev Thread-safe through Solidity's single-threaded execution model
library Id {
    struct Counter {
        uint256 _value;
    }

    /// @notice Get the current counter value
    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    /// @notice Increment the counter and return the new value
    /// @return The newly generated ID
    function next(Counter storage counter) internal returns (uint256) {
        unchecked {
            counter._value += 1;
        }
        return counter._value;
    }
}

