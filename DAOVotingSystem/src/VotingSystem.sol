// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

contract VotingSystem {
    error VotingSystem__zeroAddressNotAllowed();
    error VotingSystem__proposalValueCannotBeZero();
    error VotingSystem__durationCannotBeZero();
    error VotingSystem__invalidProposalId();
    error VotingSystem__proposalNotActive();
    error VotingSystem__voterHasAlreadyVoted();
    error VotingSystem__proposalStillActive();
    error VotingSystem__proposalAlreadyExecuted();
    error VotingSystem__ethTransferFailed();
    error VotingSystem__useCreateProposal();
    error VotingSystem__proposalDidNotPass();

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;

        uint256 yesVotes;
        uint256 noVotes;

        uint256 startTime;
        uint256 endTime;

        bool executed;
    }

    Proposal[] public proposals;

    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        address indexed proposer, address indexed target, uint256 indexed value, bytes data, uint256 duration
    );
    event Voted(uint256 indexed proposalId, bool indexed support);
    event ProposalExecuted(uint256 indexed proposalId);
    event Funded(address indexed sender, uint256 amount);

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert VotingSystem__zeroAddressNotAllowed();
        }
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        if (proposalId >= proposals.length) {
            revert VotingSystem__invalidProposalId();
        }
        _;
    }

    modifier proposalIsActive(uint256 proposalId) {
        if (block.timestamp < proposals[proposalId].startTime || block.timestamp > proposals[proposalId].endTime) {
            revert VotingSystem__proposalNotActive();
        }
        _;
    }

    function createProposal(address target, uint256 value, bytes calldata data, uint256 duration)
        public
        notZeroAddress(target)
    {
        // Checks
        if (duration == 0) {
            revert VotingSystem__durationCannotBeZero();
        }

        // Effects
        proposals.push(
            Proposal({
                proposer: msg.sender,
                target: target,
                value: value,
                data: data,
                yesVotes: 0,
                noVotes: 0,
                startTime: block.timestamp,
                endTime: block.timestamp + duration,
                executed: false
            })
        );

        // Interactions
        emit ProposalCreated(msg.sender, target, value, data, duration);
    }

    function vote(uint256 proposalId, bool support) public proposalExists(proposalId) proposalIsActive(proposalId) {
        // Checks
        if (hasVoted[proposalId][msg.sender]) {
            revert VotingSystem__voterHasAlreadyVoted();
        }

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposals[proposalId].yesVotes += 1;
        } else {
            proposals[proposalId].noVotes += 1;
        }

        // Interactions
        emit Voted(proposalId, support);
    }

    function executeProposal(uint256 proposalId) public proposalExists(proposalId) {
        // Checks
        if (block.timestamp >= proposals[proposalId].startTime && block.timestamp < proposals[proposalId].endTime) {
            revert VotingSystem__proposalStillActive();
        }

        if (proposals[proposalId].executed) {
            revert VotingSystem__proposalAlreadyExecuted();
        }

        // Effects
        bool proposalPassed = proposals[proposalId].yesVotes > proposals[proposalId].noVotes;

        if (!proposalPassed) {
            revert VotingSystem__proposalDidNotPass();
        }

        proposals[proposalId].executed = true;

        // Interactions
        (bool success,) =
            payable(proposals[proposalId].target).call{value: proposals[proposalId].value}(proposals[proposalId].data);
        if (!success) {
            revert VotingSystem__ethTransferFailed();
        }

        emit ProposalExecuted(proposalId);
    }

    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }

    fallback() external payable {
        emit Funded(msg.sender, msg.value);
    }

    /**
     *         GETTERS
     */

    function getProposal(uint256 proposalId) public view proposalExists(proposalId) returns (Proposal memory) {
        return proposals[proposalId];
    }
}
