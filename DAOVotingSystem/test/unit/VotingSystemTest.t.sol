// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {VotingSystem} from "../../src/VotingSystem.sol";

contract BadTarget {
    receive() external payable {
        revert("I always fail");
    }
    fallback() external payable {
        revert("I always fail");
    }
}

contract VotingSystemTest is Test {
    VotingSystem dao;

    address user1;
    address user2;
    address user3;
    address attacker;

    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant PROPOSAL_VALUE = 1 ether;
    uint256 constant DURATION = 1 days;

    event ProposalCreated(
        address indexed proposer, address indexed target, uint256 indexed value, bytes data, uint256 duration
    );
    event Voted(uint256 indexed proposalId, bool indexed support);
    event ProposalExecuted(uint256 indexed proposalId);
    event Funded(address indexed sender, uint256 amount);

    function setUp() external {
        dao = new VotingSystem();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        attacker = makeAddr("attacker");

        vm.deal(user1, STARTING_BALANCE);
        vm.deal(user2, STARTING_BALANCE);
        vm.deal(user3, STARTING_BALANCE);

        vm.deal(address(dao), STARTING_BALANCE);
    }

    modifier createdProposal() {
        vm.prank(user1);
        dao.createProposal(address(user2), PROPOSAL_VALUE, "", DURATION);
        _;
    }

    modifier createdMultipleProposals() {
        vm.prank(user1);
        dao.createProposal(address(user2), PROPOSAL_VALUE, "", DURATION + 1 days);
        vm.prank(user2);
        dao.createProposal(address(user3), PROPOSAL_VALUE, "", DURATION + 2 days);
        vm.prank(user3);
        dao.createProposal(address(user1), PROPOSAL_VALUE, "", DURATION + 3 days);
        _;
    }

    /**
     *             CREATE PROPOSAL
     */

    function testCreateProposalWorks() public {
        // Arrange
        address target = makeAddr("target");
        vm.prank(user1);

        // Act
        dao.createProposal(target, PROPOSAL_VALUE, "", DURATION);

        // Assert
        assertEq(dao.getProposal(0).proposer, user1);
        assertEq(dao.getProposal(0).target, target);
        assertEq(dao.getProposal(0).value, PROPOSAL_VALUE);
        assertEq(dao.getProposal(0).startTime, block.timestamp);
        assertEq(dao.getProposal(0).endTime, block.timestamp + DURATION);
        assertEq(dao.getProposal(0).yesVotes, 0);
        assertEq(dao.getProposal(0).noVotes, 0);
        assertEq(dao.getProposal(0).executed, false);
        assertEq(dao.getProposal(0).data, "");
    }

    function testZeroAddressForTargetReverts() public {
        vm.prank(user1);

        vm.expectRevert(VotingSystem.VotingSystem__zeroAddressNotAllowed.selector);
        dao.createProposal(address(0), PROPOSAL_VALUE, "", DURATION);
    }

    function testZeroDurationReverts() public {
        address target = makeAddr("target");
        vm.prank(user1);

        vm.expectRevert(VotingSystem.VotingSystem__durationCannotBeZero.selector);
        dao.createProposal(target, PROPOSAL_VALUE, "", 0);
    }

    function testCreateProposalEmitsEvent() public {
        address target = makeAddr("target");
        vm.prank(user1);

        vm.expectEmit(true, true, true, true, address(dao));
        emit ProposalCreated(user1, target, PROPOSAL_VALUE, "", DURATION);

        dao.createProposal(target, PROPOSAL_VALUE, "", DURATION);
    }

    /**
     *         VOTE
     */

    function testAnyoneCanVoteYes() public createdProposal {
        vm.prank(user2);

        dao.vote(0, true);

        assertEq(dao.getProposal(0).yesVotes, 1);
        assertEq(dao.hasVoted(0, user2), true);
    }

    function testAnyoneCanVoteNo() public createdProposal {
        vm.prank(user2);

        dao.vote(0, false);

        assertEq(dao.getProposal(0).noVotes, 1);
        assertEq(dao.hasVoted(0, user2), true);
    }

    function testDoubleVotingReverts() public createdProposal {
        vm.prank(user1);
        dao.vote(0, true);

        vm.prank(user1);
        vm.expectRevert(VotingSystem.VotingSystem__voterHasAlreadyVoted.selector);
        dao.vote(0, false);
    }

    function testVotingAfterDeadlineReverts() public createdProposal {
        vm.prank(user1);
        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(VotingSystem.VotingSystem__proposalNotActive.selector);
        dao.vote(0, true);
    }

    function testInvalidProposalIdReverts() public createdProposal {
        vm.prank(user2);

        vm.expectRevert(VotingSystem.VotingSystem__invalidProposalId.selector);
        dao.vote(1, false);
    }

    /**
            EXECUTE PROPOSAL
     */

    function testCannotExecuteActiveProposal() public createdProposal {
        vm.prank(user2);

        vm.expectRevert(VotingSystem.VotingSystem__proposalStillActive.selector);
        dao.executeProposal(0);
    }

    function testCannotExecuteIfNooneVoted() public createdProposal {
        vm.prank(user2);
        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(VotingSystem.VotingSystem__proposalDidNotPass.selector);
        dao.executeProposal(0);
    }

    function testCannotExecuteifYesAndNoHaveEqualVotes() public createdProposal {
        vm.prank(user2);
        dao.vote(0, false);
        vm.prank(user1);
        dao.vote(0, true);

        vm.prank(user3);
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(VotingSystem.VotingSystem__proposalDidNotPass.selector);
        dao.executeProposal(0);
    }

    function testProposalFailedIfNoVotesHaveMajority() public createdProposal {
        vm.prank(user2);
        dao.vote(0, false);
        vm.prank(user3);
        dao.vote(0, false);
        vm.prank(user1);
        dao.vote(0, true);

        vm.prank(user3);
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(VotingSystem.VotingSystem__proposalDidNotPass.selector);
        dao.executeProposal(0);
    }

    function testCannotExecuteTwice() public createdProposal {
        vm.startPrank(user2);
        dao.vote(0, true);
        vm.warp(block.timestamp + DURATION + 1);
        dao.executeProposal(0);

        vm.expectRevert(VotingSystem.VotingSystem__proposalAlreadyExecuted.selector);
        dao.executeProposal(0);
    }

    function testExecuteWorksIfYesVotesHaveMajority() public createdProposal {
        uint256 daoStartingBalance = address(dao).balance;
        uint256 targetStartingBalance = dao.getProposal(0).target.balance;
        vm.startPrank(user1);
        dao.vote(0, true);
        vm.warp(block.timestamp + DURATION + 1);

        dao.executeProposal(0);
        vm.stopPrank();

        assertEq(dao.getProposal(0).executed, true);
        assertEq(address(dao).balance, daoStartingBalance - dao.getProposal(0).value);
        assertEq(dao.getProposal(0).target.balance, targetStartingBalance + dao.getProposal(0).value);
    }

    function testExecuteProposalEmitsEvent() public createdProposal {
        vm.startPrank(user1);
        dao.vote(0, true);
        vm.warp(block.timestamp + DURATION + 1);

        vm.expectEmit(true, false, false, false, address(dao));
        emit ProposalExecuted(0);
        dao.executeProposal(0); 
        vm.stopPrank();
    }

    function testExecuteFailsForInvalidProposalsId() public createdProposal {
        vm.expectRevert(VotingSystem.VotingSystem__invalidProposalId.selector);
        dao.executeProposal(2);
    }

    function testExecutionRevertsIfEthTransferFails() public {
        BadTarget badTarget = new BadTarget();

        vm.prank(user1);
        dao.createProposal(address(badTarget), PROPOSAL_VALUE, "", DURATION);

        vm.prank(user2);
        dao.vote(0, true);
        vm.prank(user3);
        dao.vote(0, true);

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectRevert(VotingSystem.VotingSystem__ethTransferFailed.selector);
        dao.executeProposal(0);
    }

    /**
            MULTIPLE PROPOSALS
     */

    function testSingleUserCanVoteToDifferntProposals() public createdMultipleProposals {
        vm.startPrank(user1);
        dao.vote(0, true);
        dao.vote(1, false);
        vm.stopPrank();

        assertEq(dao.getProposal(0).yesVotes, 1);
        assertEq(dao.getProposal(0).noVotes, 0);
        assertEq(dao.getProposal(1).yesVotes, 0);
        assertEq(dao.getProposal(1).noVotes, 1);
    }

    /**
            MULTIPLE USERS
     */

    function testMultipleUsersCanVoteToSingleProposals() public createdProposal {
        vm.prank(user1);
        dao.vote(0, true);

        vm.prank(user2);
        dao.vote(0, false);

        vm.prank(user3);
        dao.vote(0, false);

        assertEq(dao.getProposal(0).yesVotes, 1);
        assertEq(dao.getProposal(0).noVotes, 2);
    }

    /**
            CONTRACT ACCEPTS ETH
     */

    function testReceiveAcceptsEthAndEmitsEvent() public {
        uint256 daoStartingBalance = address(dao).balance;
        vm.prank(user1);
        vm.expectEmit(true, false, false, true, address(dao));
        emit Funded(user1, 1 ether);
        (bool success, ) = payable(address(dao)).call{value: 1 ether}("");
        assert(success);
        assertEq(address(dao).balance, daoStartingBalance + 1 ether);
    }

    function testFallbackAcceptsEthAndEmitsEvent() public {
        uint256 daoStartingBalance = address(dao).balance;
        vm.prank(user1);
        vm.expectEmit(true, false, false, true, address(dao));
        emit Funded(user1, 1 ether);
        (bool success, ) = payable(address(dao)).call{value: 1 ether}("nonExistentFunction()");
        assert(success);
        assertEq(address(dao).balance, daoStartingBalance + 1 ether);
    }


}
