// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {EscrowContract} from "../../src/Escrow.sol";

contract EscrowTest is Test {
    EscrowContract escrow;

    address buyer;
    address seller;
    address arbiter;
    address attacker;
    uint256 escrowId;

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant ESCROW_AMOUNT = 1 ether;

    event EscrowCreated(uint256 escrowId, address buyer, address seller, uint256 amount);
    event DeliveryConfirmed(uint256 escrowId);
    event Refunded(uint256 escrowId);
    event DisputeRaised(uint256 escrowId);
    event DisputeResolved(uint256 escrowId, bool releasedToSeller);

    function setUp() external {
        escrow = new EscrowContract();

        buyer = makeAddr("buyer");
        seller = makeAddr("seller");
        arbiter = makeAddr("arbiter");
        attacker = makeAddr("attacker");

        // Fund buyer (only buyer needs ETH to create escrow)
        vm.deal(buyer, STARTING_BALANCE);
    }

    modifier createdEscrow() {
        vm.prank(buyer);
        escrow.createEscrow{value: ESCROW_AMOUNT}(seller, arbiter);
        _;
    }

    modifier disputedEscrow() {
        vm.prank(buyer);
        escrow.createEscrow{value: ESCROW_AMOUNT}(seller, arbiter);
        vm.prank(seller);
        escrow.raiseDispute(0);
        _;
    }

    modifier multipleEscrows() {
        vm.startPrank(buyer);
        escrow.createEscrow{value: 1 ether}(seller, arbiter);
        escrow.createEscrow{value: 2 ether}(seller, arbiter);
        vm.stopPrank();
        _;
    }

    /**
     *         CREATE ESCROW
     */

    function testBuyerCanCreateEscrow() public {
        // Arrange
        vm.prank(buyer);

        // Act
        escrow.createEscrow{value: ESCROW_AMOUNT}(seller, arbiter);

        // Assert
        EscrowContract.Escrow memory e = escrow.getEscrow(0);
        assertEq(e.buyer, buyer);
    }

    function testCreateEscrowWithZeroEthReverts() public {
        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__invalidAmount.selector);
        escrow.createEscrow{value: 0}(seller, arbiter);
    }

    function testCreateEscrowWithZeroAddressReverts() public {
        // Arrange
        hoax(address(0), ESCROW_AMOUNT);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__zeroAddressNotAllowed.selector);
        escrow.createEscrow{value: ESCROW_AMOUNT}(seller, arbiter);

        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__zeroAddressNotAllowed.selector);
        escrow.createEscrow{value: ESCROW_AMOUNT}(address(0), arbiter);

        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__zeroAddressNotAllowed.selector);
        escrow.createEscrow{value: ESCROW_AMOUNT}(seller, address(0));
    }

    function testCreateEscrowEmitsEvent() public {
        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectEmit(false, false, false, true, address(escrow));
        emit EscrowCreated(0, buyer, seller, ESCROW_AMOUNT);
        escrow.createEscrow{value: ESCROW_AMOUNT}(seller, arbiter);        
    }

    /**
            CONFIRM DELIVERY
     */

    function testConfirmDeliveryCalledByBuyerWorks() public createdEscrow {
        // Arrange
        vm.prank(buyer);
        uint256 escrowStartingBalance = address(escrow).balance;

        // Act
        escrow.confirmDelivery(0);
        
        // Assert
        assert(escrow.getEscrow(0).status == EscrowContract.Status.COMPLETED); 
        assertEq(address(escrow).balance, escrowStartingBalance - escrow.getEscrow(0).amount); 
        assertEq(seller.balance, escrow.getEscrow(0).amount); 
    }

    function testConfirmDeliveryCalledByNotBuyerReverts() public createdEscrow {
        // Arrange
        vm.prank(seller);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__senderNotBuyer.selector);
        escrow.confirmDelivery(0);
    }

    function testInvalidEscrowIdRevertsForConfirmDelivery() public createdEscrow {
        // Arrange
        vm.prank(seller);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__invalidEscrowId.selector);
        escrow.confirmDelivery(2);
    }

    function testConfirmDeliveryEmitsEvent() public createdEscrow {
        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectEmit(false, false, false, true, address(escrow));
        emit DeliveryConfirmed(0);
        escrow.confirmDelivery(0);
    }

    /**
            REFUND
     */

    function testRefundToBuyerWorks() public createdEscrow {
        vm.prank(buyer);
        uint256 buyerStartingBalance = buyer.balance;

        escrow.refund(0);

        assert(escrow.getEscrow(0).status == EscrowContract.Status.REFUNDED);
        assertEq(buyer.balance, buyerStartingBalance + escrow.getEscrow(0).amount);
    }

    function testOnlyBuyerCanRefund() public createdEscrow {
        vm.prank(seller);

        vm.expectRevert(EscrowContract.Escrow__senderNotBuyer.selector);
        escrow.refund(0);
    }

    function testBuyerCannotTakeRefundForCompletedEscrow() public createdEscrow {
        vm.startPrank(buyer);
        escrow.confirmDelivery(0);

        vm.expectRevert(EscrowContract.Escrow__escrowAlreadySettled.selector);
        escrow.refund(0);
    }

    function testBuyerCannotTakeRefundForDisputedEscrow() public createdEscrow {
        vm.prank(seller);
        escrow.raiseDispute(0);

        vm.prank(buyer);
        vm.expectRevert(EscrowContract.Escrow__escrowDisputed.selector);
        escrow.refund(0);
    }

    function testBuyerCannotTakeRefundForAlreadyRefundedEscrow() public createdEscrow {
        vm.startPrank(buyer);
        escrow.refund(0);

        vm.expectRevert(EscrowContract.Escrow__escrowAlreadySettled.selector);
        escrow.refund(0);
    }

    function testInvalidEscrowIdRevertsForRefund() public createdEscrow {
        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__invalidEscrowId.selector);
        escrow.refund(2);
    }

    function testRefundEmitsEvent() public createdEscrow {
        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectEmit(false, false, false, true, address(escrow));
        emit Refunded(0);
        escrow.refund(0);
    }

    /**
            DISPUTE
     */

    function testBuyerCanRaiseDispute() public createdEscrow {
        vm.prank(buyer);

        escrow.raiseDispute(0);

        assert(escrow.getEscrow(0).status == EscrowContract.Status.DISPUTED);
    }

    function testSellerCanRaiseDispute() public createdEscrow {
        vm.prank(seller);

        escrow.raiseDispute(0);

        assert(escrow.getEscrow(0).status == EscrowContract.Status.DISPUTED);
    }

    function testRaisingDisputeByNotBuyerOrSellerReverts() public createdEscrow {
        vm.prank(attacker);

        vm.expectRevert(EscrowContract.Escrow_onlyBuyerOrSellerAllowed.selector);
        escrow.raiseDispute(0);
    }

    function testRaisingDisputeRevertsForCompletedEscrow() public createdEscrow {
        vm.prank(buyer);
        escrow.confirmDelivery(0);

        vm.prank(seller);
        vm.expectRevert(EscrowContract.Escrow__escrowAlreadySettled.selector);
        escrow.raiseDispute(0);
    }

    function testRaisingDisputeRevertsForRefundedEscrow() public createdEscrow {
        vm.prank(buyer);
        escrow.refund(0);

        vm.prank(seller);
        vm.expectRevert(EscrowContract.Escrow__escrowAlreadySettled.selector);
        escrow.raiseDispute(0);
    }

    function testRaisingDisputeRevertsForAlreadyDisputedEscrow() public createdEscrow {
        vm.prank(buyer);
        escrow.raiseDispute(0);

        vm.prank(seller);
        vm.expectRevert(EscrowContract.Escrow__alreadyDisputed.selector);
        escrow.raiseDispute(0);
    }

    function testInvalidEscrowIdRevertsForRaisingDispute() public createdEscrow {
        // Arrange
        vm.prank(buyer);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__invalidEscrowId.selector);
        escrow.raiseDispute(2);
    }

    function testRaisingDisputeEmitsEvent() public createdEscrow {
        vm.prank(buyer);
        vm.expectEmit(false, false, false, true, address(escrow));
        emit DisputeRaised(0);
        escrow.raiseDispute(0);
    }

    /**
            RESOLVE
     */

    function testArbiterCanResolveDisputeInFavorOfSeller() public disputedEscrow {
        vm.prank(arbiter);
        uint256 sellerStartingBalance = seller.balance;
        escrow.resolveDispute(0, true);

        assert(escrow.getEscrow(0).status == EscrowContract.Status.COMPLETED);
        assertEq(seller.balance, sellerStartingBalance + escrow.getEscrow(0).amount);
    }

    function testArbiterCanResolveDisputeInFavorOfBuyer() public disputedEscrow {
        vm.prank(arbiter);
        uint256 buyerStartingBalance = buyer.balance;
        escrow.resolveDispute(0, false);

        assert(escrow.getEscrow(0).status == EscrowContract.Status.REFUNDED);
        assertEq(buyer.balance, buyerStartingBalance + escrow.getEscrow(0).amount);
    }

    function testResolveDisputeByNonArbiterReverts() public disputedEscrow {
        vm.prank(attacker);

        vm.expectRevert(EscrowContract.Escrow__senderNotArbiter.selector);
        escrow.resolveDispute(0, true);
    }

    function testResolveDisputeForAwaitingDeliveryEscrowReverts() public createdEscrow {
        vm.prank(arbiter);

        vm.expectRevert(EscrowContract.Escrow__escrowNotDisputed.selector);
        escrow.resolveDispute(0, false);
    }

    function testResolveDisputeForCompletedEscrowReverts() public createdEscrow {
        vm.prank(buyer);
        escrow.confirmDelivery(0);

        vm.prank(arbiter);

        vm.expectRevert(EscrowContract.Escrow__escrowAlreadySettled.selector);
        escrow.resolveDispute(0, false);
    }

    function testResolveDisputeForRefundedEscrowReverts() public createdEscrow {
        vm.prank(buyer);
        escrow.refund(0);

        vm.prank(arbiter);
        vm.expectRevert(EscrowContract.Escrow__escrowAlreadySettled.selector);
        escrow.resolveDispute(0, false);
    }

    function testInvalidEscrowIdRevertsForResolvingDispute() public disputedEscrow {
        // Arrange
        vm.prank(arbiter);

        // Act / Assert
        vm.expectRevert(EscrowContract.Escrow__invalidEscrowId.selector);
        escrow.resolveDispute(2, false);
    }

    function testResolvingDisputeEmitsEvent() public disputedEscrow {
        vm.prank(arbiter);
        vm.expectEmit(false, false, false, true, address(escrow));
        emit DisputeResolved(0, false);
        escrow.resolveDispute(0, false);
    }

    /**
            MULTIPLE ESCROWS
     */

    function testMultipleEscrowsAreIsolated() public multipleEscrows {
        assert(escrow.getEscrow(0).amount == 1 ether);
        assert(escrow.getEscrow(1).amount == 2 ether);
    }

}
 