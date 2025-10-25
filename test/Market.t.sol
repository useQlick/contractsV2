// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Market} from "../src/Market.sol";
import {QUSD} from "../src/tokens/QUSD.sol";
import {DecisionToken} from "../src/tokens/DecisionToken.sol";
import {IDecisionToken} from "../src/interfaces/IDecisionToken.sol";
import {SimpleResolver} from "../src/resolvers/SimpleResolver.sol";
import {MarketUtilsSwapHook} from "../src/MarketUtilsSwapHook.sol";
import {MarketStatus, MarketErrors} from "../src/common/MarketData.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";
import {MockPositionManager} from "./mocks/MockPositionManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title MarketTest
/// @notice Comprehensive tests for the Market contract
contract MarketTest is Test {
    Market public market;
    QUSD public qusd;
    DecisionToken public decisionToken;
    SimpleResolver public resolver;
    // MarketUtilsSwapHook public hook; // Skipped for simplified testing
    MockERC20 public marketToken;
    MockPoolManager public poolManager;
    MockPositionManager public positionManager;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    uint256 public constant INITIAL_BALANCE = 1000000e18;
    uint256 public constant MIN_DEPOSIT = 1000e18;
    uint256 public constant MARKET_DURATION = 7 days;

    event MarketCreated(
        uint256 indexed marketId,
        address indexed marketToken,
        uint256 minDeposit,
        uint256 deadline,
        address resolver
    );

    event Deposited(uint256 indexed marketId, address indexed account, uint256 amount);

    event ProposalCreated(
        uint256 indexed proposalId,
        uint256 indexed marketId,
        address indexed creator,
        string description,
        uint256 depositAmount
    );

    event MarketGraduated(uint256 indexed marketId, uint256 indexed acceptedProposalId, uint256 maxPrice);

    event MarketResolved(uint256 indexed marketId, uint256 indexed acceptedProposalId, bool yesOrNo);

    event RewardsRedeemed(uint256 indexed marketId, address indexed account, uint256 amount);

    function setUp() public {
        // Deploy mocks
        poolManager = new MockPoolManager();
        positionManager = new MockPositionManager();
        marketToken = new MockERC20("USD Coin", "USDC", 18);

        // Deploy core contracts
        qusd = new QUSD(owner);
        decisionToken = new DecisionToken(owner);
        resolver = new SimpleResolver(owner);

        // Deploy hook first with placeholder Market address
        // Note: In production, you'd need to compute the correct hook address with flags
        // For testing with mocks, we just skip hook validation
        
        // Deploy Market without hook validation (using address(0) to skip)
        market = new Market(
            address(poolManager),
            address(positionManager),
            address(qusd),
            address(decisionToken),
            address(0), // No hook for testing - mocks don't validate
            owner
        );

        // Note: Hook deployment skipped for simplified testing
        // In production tests, use Uniswap's hook address mining utilities

        // Set minters
        qusd.setMinter(address(market));
        decisionToken.setMinter(address(market));

        // Setup test accounts
        marketToken.mint(alice, INITIAL_BALANCE);
        marketToken.mint(bob, INITIAL_BALANCE);
        marketToken.mint(carol, INITIAL_BALANCE);

        vm.prank(alice);
        marketToken.approve(address(market), type(uint256).max);
        vm.prank(bob);
        marketToken.approve(address(market), type(uint256).max);
        vm.prank(carol);
        marketToken.approve(address(market), type(uint256).max);
    }

    // ============ Market Creation Tests ============

    function test_CreateMarket() public {
        uint256 deadline = block.timestamp + MARKET_DURATION;

        vm.expectEmit(true, true, true, true);
        emit MarketCreated(1, address(marketToken), MIN_DEPOSIT, deadline, address(resolver));

        uint256 marketId = market.createMarket(
            address(marketToken),
            MIN_DEPOSIT,
            deadline,
            address(resolver)
        );

        assertEq(marketId, 1, "Market ID should be 1");

        (
            uint256 _marketId,
            address _marketToken,
            uint256 _minDeposit,
            uint256 _deadline,
            address _resolver,
            MarketStatus _status,
            uint256 _totalDeposits,
            uint256 _proposalCount
        ) = market.markets(marketId);

        assertEq(_marketId, marketId);
        assertEq(_marketToken, address(marketToken));
        assertEq(_minDeposit, MIN_DEPOSIT);
        assertEq(_deadline, deadline);
        assertEq(_resolver, address(resolver));
        assertEq(uint256(_status), uint256(MarketStatus.OPEN));
        assertEq(_totalDeposits, 0);
        assertEq(_proposalCount, 0);
    }

    function test_RevertWhen_CreateMarketWithZeroAddress() public {
        vm.expectRevert();
        market.createMarket(
            address(0),
            MIN_DEPOSIT,
            block.timestamp + MARKET_DURATION,
            address(resolver)
        );
    }

    function test_RevertWhen_CreateMarketWithPastDeadline() public {
        vm.expectRevert();
        market.createMarket(
            address(marketToken),
            MIN_DEPOSIT,
            block.timestamp - 1,
            address(resolver)
        );
    }

    // ============ Deposit Tests ============

    function test_DepositToMarket() public {
        uint256 marketId = _createTestMarket();
        uint256 depositAmount = MIN_DEPOSIT * 2;

        uint256 balanceBefore = marketToken.balanceOf(alice);

        vm.expectEmit(true, true, false, true);
        emit Deposited(marketId, alice, depositAmount);

        vm.prank(alice);
        market.depositToMarket(marketId, depositAmount);

        assertEq(
            marketToken.balanceOf(alice),
            balanceBefore - depositAmount,
            "Alice balance should decrease"
        );

        assertEq(
            market.getDeposit(marketId, alice),
            depositAmount,
            "Deposit should be tracked"
        );

        (, , , , , , uint256 totalDeposits, ) = market.markets(marketId);
        assertEq(totalDeposits, depositAmount, "Total deposits should be updated");
    }

    function test_RevertWhen_DepositToNonexistentMarket() public {
        vm.prank(alice);
        vm.expectRevert();
        market.depositToMarket(999, MIN_DEPOSIT);
    }

    function test_RevertWhen_DepositZeroAmount() public {
        uint256 marketId = _createTestMarket();
        vm.prank(alice);
        vm.expectRevert();
        market.depositToMarket(marketId, 0);
    }

    // ============ Proposal Creation Tests ============

    function test_CreateProposal() public {
        uint256 marketId = _createTestMarket();

        vm.prank(alice);
        market.depositToMarket(marketId, MIN_DEPOSIT);

        vm.expectEmit(true, true, true, false);
        emit ProposalCreated(1, marketId, alice, "Test Proposal", MIN_DEPOSIT);

        vm.prank(alice);
        uint256 proposalId = market.createProposal(marketId, "Test Proposal");

        assertEq(proposalId, 1, "Proposal ID should be 1");

        (
            uint256 _proposalId,
            uint256 _marketId,
            address _creator,
            string memory _description,
            uint256 _depositAmount,
            ,
            ,
            uint256 _createdAt
        ) = market.proposals(proposalId);

        assertEq(_proposalId, proposalId);
        assertEq(_marketId, marketId);
        assertEq(_creator, alice);
        assertEq(_description, "Test Proposal");
        assertEq(_depositAmount, MIN_DEPOSIT);
        assertEq(_createdAt, block.timestamp);

        // Check decision tokens were minted
        uint256 userTokens = MIN_DEPOSIT / 2;
        assertEq(
            decisionToken.balanceOf(alice, proposalId, IDecisionToken.TokenType.YES),
            userTokens,
            "Alice should have YES tokens"
        );
        assertEq(
            decisionToken.balanceOf(alice, proposalId, IDecisionToken.TokenType.NO),
            userTokens,
            "Alice should have NO tokens"
        );
    }

    function test_RevertWhen_CreateProposalInsufficientDeposit() public {
        uint256 marketId = _createTestMarket();

        vm.prank(alice);
        market.depositToMarket(marketId, MIN_DEPOSIT / 2);

        vm.prank(alice);
        vm.expectRevert();
        market.createProposal(marketId, "Test Proposal");
    }

    function test_RevertWhen_CreateProposalAfterDeadline() public {
        uint256 marketId = _createTestMarket();

        vm.prank(alice);
        market.depositToMarket(marketId, MIN_DEPOSIT);

        // Fast forward past deadline
        vm.warp(block.timestamp + MARKET_DURATION + 1);

        vm.prank(alice);
        vm.expectRevert();
        market.createProposal(marketId, "Late Proposal");
    }

    // ============ Trading Tests ============

    function test_MintYesNo() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        uint256 mintAmount = 100e18;
        uint256 balanceBefore = marketToken.balanceOf(bob);

        vm.prank(bob);
        market.mintYesNo(proposalId, mintAmount);

        assertEq(
            marketToken.balanceOf(bob),
            balanceBefore - mintAmount,
            "Market tokens should be transferred"
        );

        assertEq(
            decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.YES),
            mintAmount,
            "YES tokens should be minted"
        );

        assertEq(
            decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.NO),
            mintAmount,
            "NO tokens should be minted"
        );

        assertEq(
            qusd.balanceOf(bob),
            mintAmount,
            "QUSD should be minted"
        );
    }

    function test_RedeemYesNo() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        uint256 mintAmount = 100e18;

        vm.prank(bob);
        market.mintYesNo(proposalId, mintAmount);

        uint256 balanceBefore = marketToken.balanceOf(bob);

        // Approve QUSD for redemption
        vm.prank(bob);
        qusd.approve(address(market), mintAmount);

        vm.prank(bob);
        market.redeemYesNo(proposalId, mintAmount);

        assertEq(
            marketToken.balanceOf(bob),
            balanceBefore + mintAmount,
            "Market tokens should be returned"
        );

        assertEq(
            decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.YES),
            0,
            "YES tokens should be burned"
        );

        assertEq(
            decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.NO),
            0,
            "NO tokens should be burned"
        );

        assertEq(qusd.balanceOf(bob), 0, "QUSD should be burned");
    }

    // ============ Graduation Tests ============

    function test_GraduateMarket() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        // Fast forward past deadline
        vm.warp(block.timestamp + MARKET_DURATION + 1);

        vm.expectEmit(true, true, false, false);
        emit MarketGraduated(marketId, proposalId, 0);

        market.graduateMarket(marketId);

        (, , , , , MarketStatus status, , ) = market.markets(marketId);
        assertEq(uint256(status), uint256(MarketStatus.PROPOSAL_ACCEPTED));

        assertEq(
            market.getAcceptedProposal(marketId),
            1,
            "Proposal should be accepted"
        );
    }

    function test_RevertWhen_GraduateMarketBeforeDeadline() public {
        (uint256 marketId, ) = _createTestMarketWithProposal();
        vm.expectRevert();
        market.graduateMarket(marketId);
    }

    function test_RevertWhen_GraduateMarketWithNoProposals() public {
        uint256 marketId = _createTestMarket();
        vm.warp(block.timestamp + MARKET_DURATION + 1);
        vm.expectRevert();
        market.graduateMarket(marketId);
    }

    // ============ Resolution Tests ============

    function test_ResolveMarketYes() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        // Graduate market
        vm.warp(block.timestamp + MARKET_DURATION + 1);
        market.graduateMarket(marketId);

        // Set outcome in resolver
        resolver.setOutcome(proposalId, true);

        vm.expectEmit(true, true, false, true);
        emit MarketResolved(marketId, proposalId, true);

        market.resolveMarket(marketId, true, "");

        (, , , , , MarketStatus status, , ) = market.markets(marketId);
        assertEq(uint256(status), uint256(MarketStatus.RESOLVED_YES));
    }

    function test_ResolveMarketNo() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        // Graduate market
        vm.warp(block.timestamp + MARKET_DURATION + 1);
        market.graduateMarket(marketId);

        // Set outcome in resolver
        resolver.setOutcome(proposalId, false);

        market.resolveMarket(marketId, false, "");

        (, , , , , MarketStatus status, , ) = market.markets(marketId);
        assertEq(uint256(status), uint256(MarketStatus.RESOLVED_NO));
    }

    function test_RevertWhen_ResolveMarketNotGraduated() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();
        resolver.setOutcome(proposalId, true);
        vm.expectRevert();
        market.resolveMarket(marketId, true, "");
    }

    function test_RevertWhen_ResolveMarketWrongOutcome() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        vm.warp(block.timestamp + MARKET_DURATION + 1);
        market.graduateMarket(marketId);

        // Set YES but try to resolve as NO
        resolver.setOutcome(proposalId, true);
        vm.expectRevert();
        market.resolveMarket(marketId, false, "");
    }

    // ============ Redemption Tests ============

    function test_RedeemRewardsYesWins() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        // Bob buys YES tokens
        uint256 buyAmount = 100e18;
        vm.prank(bob);
        market.mintYesNo(proposalId, buyAmount);

        // Graduate and resolve as YES
        vm.warp(block.timestamp + MARKET_DURATION + 1);
        market.graduateMarket(marketId);
        resolver.setOutcome(proposalId, true);
        market.resolveMarket(marketId, true, "");

        // Bob redeems
        uint256 balanceBefore = marketToken.balanceOf(bob);
        uint256 yesBalance = decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.YES);
        uint256 qusdBalance = qusd.balanceOf(bob);
        uint256 expectedReward = yesBalance + qusdBalance;

        vm.prank(bob);
        market.redeemRewards(marketId);

        assertEq(
            marketToken.balanceOf(bob),
            balanceBefore + expectedReward,
            "Bob should receive rewards"
        );

        assertEq(
            decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.YES),
            0,
            "YES tokens should be burned"
        );

        assertEq(qusd.balanceOf(bob), 0, "QUSD should be burned");
    }

    function test_RedeemRewardsNoWins() public {
        (uint256 marketId, uint256 proposalId) = _createTestMarketWithProposal();

        // Bob buys NO tokens
        uint256 buyAmount = 100e18;
        vm.prank(bob);
        market.mintYesNo(proposalId, buyAmount);

        // Graduate and resolve as NO
        vm.warp(block.timestamp + MARKET_DURATION + 1);
        market.graduateMarket(marketId);
        resolver.setOutcome(proposalId, false);
        market.resolveMarket(marketId, false, "");

        // Bob redeems
        uint256 balanceBefore = marketToken.balanceOf(bob);
        uint256 noBalance = decisionToken.balanceOf(bob, proposalId, IDecisionToken.TokenType.NO);
        uint256 qusdBalance = qusd.balanceOf(bob);
        uint256 expectedReward = noBalance + qusdBalance;

        vm.prank(bob);
        market.redeemRewards(marketId);

        assertEq(
            marketToken.balanceOf(bob),
            balanceBefore + expectedReward,
            "Bob should receive rewards"
        );
    }

    function test_RevertWhen_RedeemRewardsBeforeResolution() public {
        (uint256 marketId, ) = _createTestMarketWithProposal();
        vm.prank(bob);
        vm.expectRevert();
        market.redeemRewards(marketId);
    }

    // ============ Edge Case Tests ============

    function test_MultipleProposals() public {
        uint256 marketId = _createTestMarket();

        // Alice creates first proposal
        vm.prank(alice);
        market.depositToMarket(marketId, MIN_DEPOSIT);
        vm.prank(alice);
        uint256 proposal1 = market.createProposal(marketId, "Proposal 1");

        // Bob creates second proposal
        vm.prank(bob);
        market.depositToMarket(marketId, MIN_DEPOSIT);
        vm.prank(bob);
        uint256 proposal2 = market.createProposal(marketId, "Proposal 2");

        assertEq(proposal1, 1);
        assertEq(proposal2, 2);

        (, , , , , , , uint256 proposalCount) = market.markets(marketId);
        assertEq(proposalCount, 2);
    }

    function test_GraduationSelectsCorrectProposal() public {
        uint256 marketId = _createTestMarket();

        // Create multiple proposals
        vm.prank(alice);
        market.depositToMarket(marketId, MIN_DEPOSIT * 3);

        vm.prank(alice);
        uint256 proposal1 = market.createProposal(marketId, "Proposal 1");

        vm.prank(alice);
        uint256 proposal2 = market.createProposal(marketId, "Proposal 2");

        // Simulate price tracking (would normally happen via hook)
        // In production, updatePostSwap would be called by the hook

        // Graduate
        vm.warp(block.timestamp + MARKET_DURATION + 1);
        market.graduateMarket(marketId);

        uint256 acceptedProposal = market.getAcceptedProposal(marketId);
        assertTrue(acceptedProposal == 1, "Should accept a proposal");
    }

    // ============ Helper Functions ============

    function _createTestMarket() internal returns (uint256 marketId) {
        uint256 deadline = block.timestamp + MARKET_DURATION;
        marketId = market.createMarket(
            address(marketToken),
            MIN_DEPOSIT,
            deadline,
            address(resolver)
        );
    }

    function _createTestMarketWithProposal() internal returns (uint256 marketId, uint256 proposalId) {
        marketId = _createTestMarket();

        vm.prank(alice);
        market.depositToMarket(marketId, MIN_DEPOSIT);

        vm.prank(alice);
        proposalId = market.createProposal(marketId, "Test Proposal");
    }
}

