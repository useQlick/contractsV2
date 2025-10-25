// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

/// @title MockPoolManager
/// @notice Minimal mock of Uniswap v4 PoolManager for testing
/// @dev Only implements methods needed for Market contract testing
contract MockPoolManager {
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    mapping(PoolId => bool) public poolInitialized;

    event PoolInitialized(PoolId indexed poolId);
    
    function initialize(
        PoolKey memory key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external returns (int24 tick) {
        // Mock initialization
        // In real PoolManager, this would set up the pool
        return 0; // Return tick 0 for 1:1 price
    }

    function isPoolInitialized(PoolId poolId) external view returns (bool) {
        return poolInitialized[poolId];
    }

    // Minimal swap implementation for testing
    function swap(
        PoolKey memory,
        SwapParams memory,
        bytes calldata
    ) external returns (BalanceDelta) {
        // Mock swap - just return zero deltas
        return BalanceDelta.wrap(0);
    }

    function modifyLiquidity(
        PoolKey memory,
        ModifyLiquidityParams memory,
        bytes calldata
    ) external returns (BalanceDelta, BalanceDelta) {
        // Mock liquidity modification
        return (BalanceDelta.wrap(0), BalanceDelta.wrap(0));
    }

    function donate(
        PoolKey memory,
        uint256,
        uint256,
        bytes calldata
    ) external returns (BalanceDelta) {
        return BalanceDelta.wrap(0);
    }

    function sync(Currency) external {}

    function take(Currency, address, uint256) external {}

    function settle() external returns (uint256) {
        return 0;
    }

    function settleFor(address) external returns (uint256) {
        return 0;
    }

    function clear(Currency, uint256) external {}

    function mint(address, uint256, uint256) external {}

    function burn(address, uint256, uint256) external {}
}

