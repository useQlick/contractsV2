// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleResolver} from "../../src/resolvers/SimpleResolver.sol";

contract SimpleResolverTest is Test {
    SimpleResolver public resolver;

    address public owner = address(this);
    address public alice = makeAddr("alice");

    uint256 public constant PROPOSAL_ID = 1;

    function setUp() public {
        resolver = new SimpleResolver(owner);
    }

    function test_SetOutcomeYes() public {
        resolver.setOutcome(PROPOSAL_ID, true);

        (bool outcome, bool isSet) = resolver.getOutcome(PROPOSAL_ID);
        assertTrue(isSet);
        assertTrue(outcome);
    }

    function test_SetOutcomeNo() public {
        resolver.setOutcome(PROPOSAL_ID, false);

        (bool outcome, bool isSet) = resolver.getOutcome(PROPOSAL_ID);
        assertTrue(isSet);
        assertFalse(outcome);
    }

    function test_RevertWhen_SetOutcomeNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        resolver.setOutcome(PROPOSAL_ID, true);
    }

    function test_RevertWhen_SetOutcomeTwice() public {
        resolver.setOutcome(PROPOSAL_ID, true);
        vm.expectRevert();
        resolver.setOutcome(PROPOSAL_ID, false);
    }

    function test_UpdateOutcome() public {
        resolver.setOutcome(PROPOSAL_ID, true);
        resolver.updateOutcome(PROPOSAL_ID, false);

        (bool outcome, bool isSet) = resolver.getOutcome(PROPOSAL_ID);
        assertTrue(isSet);
        assertFalse(outcome);
    }

    function test_VerifyResolutionSuccess() public {
        resolver.setOutcome(PROPOSAL_ID, true);
        resolver.verifyResolution(PROPOSAL_ID, true, "");
        // Should not revert
    }

    function test_RevertWhen_VerifyResolutionNotSet() public {
        vm.expectRevert();
        resolver.verifyResolution(PROPOSAL_ID, true, "");
    }

    function test_RevertWhen_VerifyResolutionMismatch() public {
        resolver.setOutcome(PROPOSAL_ID, true);
        vm.expectRevert();
        resolver.verifyResolution(PROPOSAL_ID, false, "");
    }
}

