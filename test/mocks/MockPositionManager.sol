// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockPositionManager
/// @notice Minimal mock of Uniswap v4 PositionManager for testing
/// @dev Only implements methods needed for Market contract testing
contract MockPositionManager {
    event LiquidityAdded(address indexed owner, uint256 amount);

    function multicall(bytes[] calldata data)
        external
        payable
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        
        // Mock multicall - just return empty results
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = "";
        }

        return results;
    }

    function mint(
        address,
        uint256,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    ) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        // Mock mint - return dummy values
        return (1, 1000000, 1000000, 1000000);
    }

    function increaseLiquidity(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        return (1000000, 1000000, 1000000);
    }

    function decreaseLiquidity(
        uint256,
        uint128,
        uint256,
        uint256,
        uint256
    ) external returns (uint256 amount0, uint256 amount1) {
        return (1000000, 1000000);
    }

    function collect(
        uint256,
        address,
        uint128,
        uint128
    ) external returns (uint256 amount0, uint256 amount1) {
        return (0, 0);
    }

    function burn(uint256) external {}
}

