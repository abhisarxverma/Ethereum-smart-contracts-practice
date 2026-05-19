// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";

contract VaultTest is Test {
    Vault vault;

    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant AMOUNT = 0.1 ether;

    function setUp() external {
        DeployVault deployVault = new DeployVault();
        vault = deployVault.run();
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDepositStoresCorrectData() public {
        vm.prank(USER);
        vault.deposit{value: AMOUNT}(5);

        Vault.Deposit memory dep = vault.seeDeposit(USER, 0);

        assertEq(dep.amount, AMOUNT);
        assertEq(dep.unlockTime, block.timestamp + 5 days);
    }

    function testDepositRevertsIfBelowMinimum() public {
        vm.prank(USER);
        vm.expectRevert();
        vault.deposit{value: 0.001 ether}(5);
    }

    function testDepositRevertsIfZeroDuration() public {
        vm.prank(USER);
        vm.expectRevert();
        vault.deposit{value: AMOUNT}(0);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function testWithdrawWorks() public {
        vm.startPrank(USER);

        vault.deposit{value: AMOUNT}(5);

        vm.warp(block.timestamp + 6 days);

        uint256 startingBalance = USER.balance;

        vault.withdraw(0);

        assertEq(USER.balance, startingBalance + AMOUNT);

        vm.stopPrank();
    }

    function testWithdrawRevertsIfNotUnlocked() public {
        vm.startPrank(USER);

        vault.deposit{value: AMOUNT}(5);

        vm.expectRevert();
        vault.withdraw(0);

        vm.stopPrank();
    }

    function testWithdrawRevertsIfInvalidIndex() public {
        vm.prank(USER);
        vm.expectRevert();
        vault.withdraw(0);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE DEPOSITS TESTS
    //////////////////////////////////////////////////////////////*/

    function testMultipleDepositsAndWithdraw() public {
        vm.startPrank(USER);

        vault.deposit{value: AMOUNT}(5); 
        vault.deposit{value: AMOUNT}(10); 

        vm.warp(block.timestamp + 6 days);

        vault.withdraw(0);
        vm.stopPrank();

        Vault.Deposit memory dep = vault.seeDeposit(USER, 0);

        assertEq(dep.amount, AMOUNT);

    }

    function testSwapAndPopWorksCorrectly() public {
        vm.startPrank(USER);

        vault.deposit{value: AMOUNT}(5);
        vault.deposit{value: AMOUNT}(10); 

        vm.warp(block.timestamp + 11 days);

        vault.withdraw(0);
        vm.stopPrank();

        Vault.Deposit memory dep = vault.seeDeposit(USER, 0);

        assertEq(dep.unlockTime, block.timestamp - 1 days);

    }

    /*//////////////////////////////////////////////////////////////
                        MULTI USER TESTS
    //////////////////////////////////////////////////////////////*/

    function testUsersAreIndependent() public {
        vm.prank(USER);
        vault.deposit{value: AMOUNT}(5);

        vm.prank(USER2);
        vault.deposit{value: AMOUNT}(10);

        vm.warp(block.timestamp + 6 days);

        vm.prank(USER);
        vault.withdraw(0);

        Vault.Deposit memory dep = vault.seeDeposit(USER2, 0);
        assertEq(dep.amount, AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDepositEmitsEvent() public {
        vm.prank(USER);

        vm.expectEmit(true, true, true, false);
        emit Vault.Deposited(USER, AMOUNT, block.timestamp + 5 days);

        vault.deposit{value: AMOUNT}(5);
    }

    function testWithdrawEmitsEvent() public {
        vm.startPrank(USER);

        vault.deposit{value: AMOUNT}(5);
        vm.warp(block.timestamp + 6 days);

        vm.expectEmit(true, true, false, false);
        emit Vault.Withdrawn(USER, AMOUNT);

        vault.withdraw(0);

        vm.stopPrank();
    }
}