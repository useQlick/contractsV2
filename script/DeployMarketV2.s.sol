// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MarketV2} from "../src/MarketV2.sol";
import {QUSD} from "../src/tokens/QUSD.sol";
import {DecisionTokenFactory} from "../src/tokens/DecisionTokenFactory.sol";
import {SimpleResolver} from "../src/resolvers/SimpleResolver.sol";
import {MarketUtilsSwapHook} from "../src/MarketUtilsSwapHook.sol";
import {MarketView} from "../src/MarketView.sol";
import {MockPoolManager} from "../test/mocks/MockPoolManager.sol";
import {MockPositionManager} from "../test/mocks/MockPositionManager.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title DeployMarketV2
/// @notice Complete deployment script for production-ready Market system
contract DeployMarketV2 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== Qlick Market V2 Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy or use existing Pool Manager and Position Manager
        address poolManager;
        address positionManager;
        address testMarketToken;

        bool useMocks = vm.envOr("USE_MOCKS", true);

        if (useMocks) {
            console2.log(">>> Deploying MOCK contracts for testing...");
            poolManager = address(new MockPoolManager());
            positionManager = address(new MockPositionManager());
            
            // Deploy test market token (USDC-like)
            MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
            testMarketToken = address(usdc);
            
            // Mint some tokens to deployer for testing
            usdc.mint(deployer, 1000000e6); // 1M USDC
            
            console2.log("  MockPoolManager:", poolManager);
            console2.log("  MockPositionManager:", positionManager);
            console2.log("  Test Market Token (USDC):", testMarketToken);
        } else {
            poolManager = vm.envAddress("POOL_MANAGER");
            positionManager = vm.envAddress("POSITION_MANAGER");
            testMarketToken = vm.envOr("MARKET_TOKEN", address(0));
            
            console2.log(">>> Using PRODUCTION Uniswap v4 contracts");
            console2.log("  PoolManager:", poolManager);
            console2.log("  PositionManager:", positionManager);
        }

        console2.log("");
        console2.log(">>> Deploying core contracts...");

        // 1. Deploy QUSD
        QUSD qusd = new QUSD(deployer);
        console2.log("  QUSD:", address(qusd));

        // 2. Deploy DecisionTokenFactory (needs Market address, will be set later)
        DecisionTokenFactory tokenFactory = new DecisionTokenFactory(address(0)); // Placeholder
        console2.log("  DecisionTokenFactory:", address(tokenFactory));

        // 3. Deploy SimpleResolver
        SimpleResolver resolver = new SimpleResolver(deployer);
        console2.log("  SimpleResolver:", address(resolver));

        // 4. Deploy MarketV2 (without hook first)
        MarketV2 market = new MarketV2(
            poolManager,
            positionManager,
            address(qusd),
            address(tokenFactory),
            address(0), // No hook yet
            deployer
        );
        console2.log("  MarketV2:", address(market));

        // 5. Update tokenFactory with correct market address
        // Note: In production, deploy tokenFactory after market or use a factory pattern
        console2.log("  Note: TokenFactory needs to be redeployed with correct market address");
        
        DecisionTokenFactory tokenFactoryCorrect = new DecisionTokenFactory(address(market));
        console2.log("  DecisionTokenFactory (corrected):", address(tokenFactoryCorrect));

        // Re-deploy market with correct factory
        MarketV2 marketCorrected = new MarketV2(
            poolManager,
            positionManager,
            address(qusd),
            address(tokenFactoryCorrect),
            address(0), // Will add hook next
            deployer
        );
        console2.log("  MarketV2 (corrected):", address(marketCorrected));

        // 6. Deploy MarketUtilsSwapHook
        MarketUtilsSwapHook hook = new MarketUtilsSwapHook(
            IPoolManager(poolManager),
            address(marketCorrected)
        );
        console2.log("  MarketUtilsSwapHook:", address(hook));

        // 7. Deploy MarketView for frontend
        MarketView marketView = new MarketView(
            address(marketCorrected),
            poolManager
        );
        console2.log("  MarketView:", address(marketView));

        // 8. Configure permissions
        console2.log("");
        console2.log(">>> Configuring permissions...");
        
        qusd.setMinter(address(marketCorrected));
        console2.log("  QUSD minter set to Market");

        // Note: In production with hooks, need to mine correct hook address
        console2.log("");
        console2.log(">>> Deployment complete!");
        console2.log("");

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("=== DEPLOYMENT SUMMARY ===");
        console2.log("Network:", useMocks ? "Local/Mock" : "Production");
        console2.log("");
        console2.log("Core Contracts:");
        console2.log("  Market:", address(marketCorrected));
        console2.log("  QUSD:", address(qusd));
        console2.log("  TokenFactory:", address(tokenFactoryCorrect));
        console2.log("  Resolver:", address(resolver));
        console2.log("  Hook:", address(hook));
        console2.log("  MarketView:", address(marketView));
        console2.log("");
        console2.log("Infrastructure:");
        console2.log("  PoolManager:", poolManager);
        console2.log("  PositionManager:", positionManager);
        if (useMocks && testMarketToken != address(0)) {
            console2.log("  Test Market Token:", testMarketToken);
        }
        console2.log("");
        console2.log("=========================");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Verify contracts on block explorer");
        console2.log("2. Create a market using Market.createMarket()");
        console2.log("3. Users deposit and create proposals");
        console2.log("4. Trading happens on Uniswap v4 pools");
        console2.log("5. Use MarketView for frontend queries");
        console2.log("");

        // Save addresses to file for frontend
        string memory addresses = string.concat(
            "{\n",
            '  "market": "', vm.toString(address(marketCorrected)), '",\n',
            '  "qusd": "', vm.toString(address(qusd)), '",\n',
            '  "tokenFactory": "', vm.toString(address(tokenFactoryCorrect)), '",\n',
            '  "resolver": "', vm.toString(address(resolver)), '",\n',
            '  "hook": "', vm.toString(address(hook)), '",\n',
            '  "marketView": "', vm.toString(address(marketView)), '",\n',
            '  "poolManager": "', vm.toString(poolManager), '",\n',
            '  "positionManager": "', vm.toString(positionManager), '"'
        );

        if (useMocks && testMarketToken != address(0)) {
            addresses = string.concat(
                addresses,
                ',\n',
                '  "testMarketToken": "', vm.toString(testMarketToken), '"'
            );
        }

        addresses = string.concat(addresses, "\n}");

        vm.writeFile("deployments/latest.json", addresses);
        console2.log("Addresses saved to: deployments/latest.json");
    }
}

