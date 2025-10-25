// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {QUSD} from "../../src/tokens/QUSD.sol";

contract QUSDTest is Test {
    QUSD public qusd;

    address public owner = address(this);
    address public minter = makeAddr("minter");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        qusd = new QUSD(owner);
        qusd.setMinter(minter);
    }

    function test_Metadata() public {
        assertEq(qusd.name(), "Qlick USD");
        assertEq(qusd.symbol(), "QUSD");
        assertEq(qusd.decimals(), 18);
    }

    function test_SetMinter() public {
        address newMinter = makeAddr("newMinter");
        qusd.setMinter(newMinter);
        assertEq(qusd.minter(), newMinter);
    }

    function test_RevertWhen_SetMinterNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        qusd.setMinter(alice);
    }

    function test_Mint() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        qusd.mint(alice, amount);

        assertEq(qusd.balanceOf(alice), amount);
        assertEq(qusd.totalSupply(), amount);
    }

    function test_RevertWhen_MintNotMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        qusd.mint(alice, 1000e18);
    }

    function test_Burn() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        qusd.mint(alice, amount);

        vm.prank(minter);
        qusd.burn(alice, 500e18);

        assertEq(qusd.balanceOf(alice), 500e18);
        assertEq(qusd.totalSupply(), 500e18);
    }

    function test_RevertWhen_BurnNotMinter() public {
        vm.prank(minter);
        qusd.mint(alice, 1000e18);

        vm.prank(alice);
        vm.expectRevert();
        qusd.burn(alice, 500e18);
    }

    function test_Transfer() public {
        uint256 amount = 1000e18;

        vm.prank(minter);
        qusd.mint(alice, amount);

        vm.prank(alice);
        qusd.transfer(bob, 400e18);

        assertEq(qusd.balanceOf(alice), 600e18);
        assertEq(qusd.balanceOf(bob), 400e18);
    }
}

