// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DecisionToken} from "../../src/tokens/DecisionToken.sol";
import {IDecisionToken} from "../../src/interfaces/IDecisionToken.sol";

contract DecisionTokenTest is Test {
    DecisionToken public decisionToken;

    address public owner = address(this);
    address public minter = makeAddr("minter");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant PROPOSAL_ID = 1;

    function setUp() public {
        decisionToken = new DecisionToken(owner);
        decisionToken.setMinter(minter);
    }

    function test_SetMinter() public {
        address newMinter = makeAddr("newMinter");
        decisionToken.setMinter(newMinter);
        assertEq(decisionToken.minter(), newMinter);
    }

    function test_RevertWhen_SetMinterNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        decisionToken.setMinter(alice);
    }

    function test_MintYES() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, amount);

        assertEq(
            decisionToken.balanceOf(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES),
            amount
        );
    }

    function test_MintNO() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.NO, amount);

        assertEq(
            decisionToken.balanceOf(alice, PROPOSAL_ID, IDecisionToken.TokenType.NO),
            amount
        );
    }

    function test_RevertWhen_MintNotMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, 1000e18);
    }

    function test_BurnYES() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, amount);

        vm.prank(minter);
        decisionToken.burn(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, 400e18);

        assertEq(
            decisionToken.balanceOf(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES),
            600e18
        );
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, 100e18);

        vm.prank(minter);
        vm.expectRevert();
        decisionToken.burn(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, 200e18);
    }

    function test_Transfer() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, amount);

        vm.prank(minter);
        decisionToken.transfer(
            alice,
            bob,
            PROPOSAL_ID,
            IDecisionToken.TokenType.YES,
            400e18
        );

        assertEq(
            decisionToken.balanceOf(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES),
            600e18
        );
        assertEq(
            decisionToken.balanceOf(bob, PROPOSAL_ID, IDecisionToken.TokenType.YES),
            400e18
        );
    }

    function test_MultipleProposalsSeparate() public {
        uint256 proposal1 = 1;
        uint256 proposal2 = 2;
        uint256 amount = 1000e18;

        vm.prank(minter);
        decisionToken.mint(alice, proposal1, IDecisionToken.TokenType.YES, amount);

        vm.prank(minter);
        decisionToken.mint(alice, proposal2, IDecisionToken.TokenType.YES, amount);

        assertEq(
            decisionToken.balanceOf(alice, proposal1, IDecisionToken.TokenType.YES),
            amount
        );
        assertEq(
            decisionToken.balanceOf(alice, proposal2, IDecisionToken.TokenType.YES),
            amount
        );
    }

    function test_YesAndNoSeparate() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES, amount);

        vm.prank(minter);
        decisionToken.mint(alice, PROPOSAL_ID, IDecisionToken.TokenType.NO, amount);

        assertEq(
            decisionToken.balanceOf(alice, PROPOSAL_ID, IDecisionToken.TokenType.YES),
            amount
        );
        assertEq(
            decisionToken.balanceOf(alice, PROPOSAL_ID, IDecisionToken.TokenType.NO),
            amount
        );
    }
}

