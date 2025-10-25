// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Market} from "../src/Market.sol";
import {QUSD} from "../src/tokens/QUSD.sol";
import {DecisionToken} from "../src/tokens/DecisionToken.sol";
import {SimpleResolver} from "../src/resolvers/SimpleResolver.sol";
import {MarketUtilsSwapHook} from "../src/MarketUtilsSwapHook.sol";
import {MockPoolManager} from "../test/mocks/MockPoolManager.sol";
import {MockPositionManager} from "../test/mocks/MockPositionManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title DeployMarket
/// @notice Deployment script for the Market system
/// @dev Can deploy with mocks or real Uniswap v4 addresses
contract DeployMarket is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying from:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy or use existing Pool Manager
        address poolManager;
        address positionManager;

        // Check if we're using mocks or real addresses
        if (vm.envOr("USE_MOCKS", true)) {
            console2.log("Deploying mock contracts...");
            poolManager = address(new MockPoolManager());
            positionManager = address(new MockPositionManager());
        } else {
            // Use real Uniswap v4 addresses (set in .env)
            poolManager = vm.envAddress("POOL_MANAGER");
            positionManager = vm.envAddress("POSITION_MANAGER");
        }

        console2.log("Pool Manager:", poolManager);
        console2.log("Position Manager:", positionManager);

        // Deploy QUSD
        QUSD qusd = new QUSD(deployer);
        console2.log("QUSD deployed at:", address(qusd));

        // Deploy DecisionToken
        DecisionToken decisionToken = new DecisionToken(deployer);
        console2.log("DecisionToken deployed at:", address(decisionToken));

        // Deploy SimpleResolver
        SimpleResolver resolver = new SimpleResolver(deployer);
        console2.log("SimpleResolver deployed at:", address(resolver));

        // Deploy Market with placeholder hook
        Market market = new Market(
            poolManager,
            positionManager,
            address(qusd),
            address(decisionToken),
            address(0x1), // Placeholder for hook
            deployer
        );
        console2.log("Market deployed at:", address(market));

        // Deploy MarketUtilsSwapHook
        MarketUtilsSwapHook hook = new MarketUtilsSwapHook(
            IPoolManager(poolManager),
            address(market)
        );
        console2.log("MarketUtilsSwapHook deployed at:", address(hook));

        // Set minters
        qusd.setMinter(address(market));
        console2.log("QUSD minter set to Market");

        decisionToken.setMinter(address(market));
        console2.log("DecisionToken minter set to Market");

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("QUSD:", address(qusd));
        console2.log("DecisionToken:", address(decisionToken));
        console2.log("Market:", address(market));
        console2.log("SimpleResolver:", address(resolver));
        console2.log("MarketUtilsSwapHook:", address(hook));
        console2.log("Pool Manager:", poolManager);
        console2.log("Position Manager:", positionManager);
        console2.log("=========================\n");
    }
}

