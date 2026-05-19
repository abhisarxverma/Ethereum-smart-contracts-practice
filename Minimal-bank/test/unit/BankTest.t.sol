// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../../src/Bank.sol";
import {DeployBank} from "../../script/DeployBank.s.sol";

contract BankTest is Test {
    Bank bank;
    address USER = makeAddr("test-user");
    uint256 DEPOSIT_AMOUNT = 0.2 ether;
    uint256 STARTING_BALANCE = 1 ether;
    uint256 WITHDRAW_AMOUNT = 0.1 ether;

    event Deposited(address indexed _address, uint256 indexed _amount);
    event Withdrawn(address indexed _address, uint256 indexed _amount);

    function setUp() external {
        DeployBank deployBank = new DeployBank();
        bank = deployBank.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    modifier deposited() {
        vm.prank(USER);
        bank.deposit{value: DEPOSIT_AMOUNT}();
        _;
    }

    function testDepositUpdatesBalance(uint256 _amount) public {
        // Arrange
        vm.assume(_amount > 0.1 ether && _amount <= STARTING_BALANCE);
        vm.prank(USER);

        // Act
        bank.deposit{value: _amount}();

        // Assert
        assertEq(bank.balanceOf(USER), _amount);
    }

    function testWithdrawWorks() public deposited {
        // Arrange
        vm.prank(USER);

        // Act
        bank.withdraw(WITHDRAW_AMOUNT);

        // Assert
        assertEq(bank.balanceOf(USER), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
        assertEq(payable(USER).balance, (STARTING_BALANCE - DEPOSIT_AMOUNT) + WITHDRAW_AMOUNT);
    }

    function testWithdrawFailsIfOverBalance() public deposited {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert();
        bank.withdraw(DEPOSIT_AMOUNT + 0.1 ether);
    }

    function testDepositRevertsIfBelowMinimum() public {
        vm.prank(USER);
        vm.expectRevert();
        bank.deposit{value: 0.001 ether}();
    }

    function testWithdrawRevertsForZeroAmount() public {
        vm.prank(USER);
        vm.expectRevert();
        bank.withdraw(0);
    }

    function testDepositEmitsEvent() public {
        vm.prank(USER);

        vm.expectEmit(true, true, false, false, address(bank));
        emit Deposited(USER, DEPOSIT_AMOUNT);

        bank.deposit{value: DEPOSIT_AMOUNT}();
    }

    function testWithdrawEmitsEvent() public deposited {
        vm.prank(USER);

        vm.expectEmit(true, true, false, false, address(bank));
        emit Withdrawn(USER, WITHDRAW_AMOUNT);

        bank.withdraw(WITHDRAW_AMOUNT);
    }

    function testMultipleUsers() public {
        address USER2 = makeAddr("user2");

        vm.deal(USER, 1 ether);
        vm.deal(USER2, 1 ether);

        // USER deposits
        vm.prank(USER);
        bank.deposit{value: 0.2 ether}();

        // USER2 deposits
        vm.prank(USER2);
        bank.deposit{value: 0.5 ether}();

        // Check balances
        assertEq(bank.balanceOf(USER), 0.2 ether);
        assertEq(bank.balanceOf(USER2), 0.5 ether);

        // USER withdraws
        vm.prank(USER);
        bank.withdraw(0.1 ether);

        // Ensure USER2 unaffected
        assertEq(bank.balanceOf(USER2), 0.5 ether);
    }
}
