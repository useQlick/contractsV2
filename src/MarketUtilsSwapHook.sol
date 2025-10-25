// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IMarket} from "./interfaces/IMarket.sol";

/// @title MarketUtilsSwapHook
/// @notice Uniswap v4 hook that enforces market rules and tracks prices for prediction markets
/// @dev Integrates with Market.sol to validate swaps and update price tracking
contract MarketUtilsSwapHook is BaseHook {
    /// @notice Reference to the Market contract
    IMarket public immutable market;

    /// @notice Accumulated tick for price calculation
    mapping(bytes32 => int24) private accumulatedTick;

    /// @notice Swap count for averaging
    mapping(bytes32 => uint256) private swapCount;

    error Unauthorized();
    error MarketSwapValidationFailed();

    /// @param _poolManager Uniswap v4 Pool Manager
    /// @param _market Market contract address
    constructor(IPoolManager _poolManager, address _market) BaseHook(_poolManager) {
        if (_market == address(0)) revert Unauthorized();
        market = IMarket(_market);
    }

    /// @notice Define which hooks this contract implements
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Called before a swap to validate market state
    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        // Validate swap with Market contract
        try market.validateSwap(key) {
            // Validation passed
        } catch {
            revert MarketSwapValidationFailed();
        }

        // Calculate approximate tick from swap
        // Note: This is a simplified version. In production, you'd calculate more accurately
        bytes32 poolKey = keccak256(abi.encode(key));
        
        // Estimate tick based on swap parameters
        // In a real implementation, this would be more sophisticated
        int24 estimatedTick = _estimateTickFromSwap(params);
        
        accumulatedTick[poolKey] += estimatedTick;
        swapCount[poolKey]++;

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @notice Called after a swap to update price tracking
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        bytes32 poolKey = keccak256(abi.encode(key));
        
        // Calculate average tick
        int24 avgTick = 0;
        if (swapCount[poolKey] > 0) {
            avgTick = accumulatedTick[poolKey] / int24(int256(swapCount[poolKey]));
        }

        // Update Market contract with price information
        market.updatePostSwap(key, avgTick);

        // Reset accumulator for next batch
        accumulatedTick[poolKey] = 0;
        swapCount[poolKey] = 0;

        return (BaseHook.afterSwap.selector, 0);
    }

    /// @notice Estimate tick from swap parameters (simplified)
    /// @dev In production, this should be calculated more precisely using pool state
    function _estimateTickFromSwap(SwapParams calldata params) private pure returns (int24) {
        // Simplified estimation based on swap direction
        // In reality, you'd query current pool state and calculate actual tick
        if (params.zeroForOne) {
            return -100; // Moving down in price
        } else {
            return 100; // Moving up in price
        }
    }
}

