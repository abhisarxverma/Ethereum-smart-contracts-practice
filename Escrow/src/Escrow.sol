// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

contract EscrowContract {
    error Escrow__senderNotBuyer();
    error Escorw__invalidAddress();
    error Escrow__invalidEscrowId();
    error Escrow__escrowNotAwaitingDelivery();
    error Escrow__ethTransferFailed();
    error Escrow__senderNotArbiter();
    error Escrow__escrowAlreadySettled();
    error Escrow__alreadyDisputed();
    error Escrow__escrowNotDisputed();
    error Escrow__escrowDisputed();
    error Escrow__zeroAddressNotAllowed();
    error Escrow__invalidAmount();
    error Escrow__useCreateEscrow();
    error Escrow_onlyBuyerOrSellerAllowed();

    enum Status {
        AWAITING_DELIVERY,
        COMPLETED,
        REFUNDED,
        DISPUTED
    }

    struct Escrow {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        Status status;
    }

    Escrow[] public escrows;

    event EscrowCreated(uint256 escrowId, address buyer, address seller, uint256 amount);
    event DeliveryConfirmed(uint256 escrowId);
    event Refunded(uint256 escrowId);
    event DisputeRaised(uint256 escrowId);
    event DisputeResolved(uint256 escrowId, bool releasedToSeller);

    /**
     *         MODIFIERS
     */

    modifier onlyBuyer(uint256 escrowId) {
        if (msg.sender != escrows[escrowId].buyer) {
            revert Escrow__senderNotBuyer();
        }
        _;
    }

    modifier escrowExist(uint256 escrowId) {
        if (escrowId >= escrows.length) {
            revert Escrow__invalidEscrowId();
        }
        _;
    }

    modifier onlyArbiter(uint256 escrowId) {
        if (msg.sender != escrows[escrowId].arbiter) {
            revert Escrow__senderNotArbiter();
        }
        _;
    }

    modifier escrowNotSettled(uint256 escrowId) {
        if (escrows[escrowId].status == Status.COMPLETED || escrows[escrowId].status == Status.REFUNDED) {
            revert Escrow__escrowAlreadySettled();
        }
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert Escrow__zeroAddressNotAllowed();
        }
        _;
    }

    modifier onlyBuyerOrSeller(uint256 escrowId) {
        if (msg.sender != escrows[escrowId].buyer && msg.sender != escrows[escrowId].seller) {
            revert Escrow_onlyBuyerOrSellerAllowed();
        }
        _;
    }

    function createEscrow(address seller, address arbiter)
        public
        payable
        notZeroAddress(seller)
        notZeroAddress(arbiter)
    {
        // Checks
        if (msg.sender == address(0)) {
            revert Escrow__zeroAddressNotAllowed();
        }
        if (msg.value == 0) {
            revert Escrow__invalidAmount();
        }

        // Effects
        Escrow memory newEscrow = Escrow({
            buyer: msg.sender, seller: seller, arbiter: arbiter, amount: msg.value, status: Status.AWAITING_DELIVERY
        });

        escrows.push(newEscrow);

        // Interactions
        emit EscrowCreated(escrows.length - 1, msg.sender, seller, msg.value);
    }

    function confirmDelivery(uint256 escrowId) public escrowExist(escrowId) onlyBuyer(escrowId) {
        // Checks
        if (escrows[escrowId].status != Status.AWAITING_DELIVERY) {
            revert Escrow__escrowNotAwaitingDelivery();
        }

        // Effects
        escrows[escrowId].status = Status.COMPLETED;

        // Interactions
        (bool success,) = payable(escrows[escrowId].seller).call{value: escrows[escrowId].amount}("");
        if (!success) {
            revert Escrow__ethTransferFailed();
        }

        emit DeliveryConfirmed(escrowId);
    }

    function refund(uint256 escrowId) public escrowExist(escrowId) onlyBuyer(escrowId) escrowNotSettled(escrowId) {
        if (escrows[escrowId].status == Status.DISPUTED) {
            revert Escrow__escrowDisputed();
        }

        escrows[escrowId].status = Status.REFUNDED;

        (bool success,) = payable(escrows[escrowId].buyer).call{value: escrows[escrowId].amount}("");
        if (!success) {
            revert Escrow__ethTransferFailed();
        }

        emit Refunded(escrowId);
    }

    function raiseDispute(uint256 escrowId)
        public
        escrowExist(escrowId)
        escrowNotSettled(escrowId)
        onlyBuyerOrSeller(escrowId)
    {
        if (escrows[escrowId].status == Status.DISPUTED) {
            revert Escrow__alreadyDisputed();
        }

        escrows[escrowId].status = Status.DISPUTED;

        emit DisputeRaised(escrowId);
    }

    function resolveDispute(uint256 escrowId, bool releasedToSeller)
        public
        escrowExist(escrowId)
        onlyArbiter(escrowId)
        escrowNotSettled(escrowId)
    {
        if (escrows[escrowId].status != Status.DISPUTED) {
            revert Escrow__escrowNotDisputed();
        }

        escrows[escrowId].status = releasedToSeller ? Status.COMPLETED : Status.REFUNDED;

        bool success;

        if (releasedToSeller) {
            (success,) = payable(escrows[escrowId].seller).call{value: escrows[escrowId].amount}("");
        } else {
            (success,) = payable(escrows[escrowId].buyer).call{value: escrows[escrowId].amount}("");
        }

        if (!success) {
            revert Escrow__ethTransferFailed();
        }

        emit DisputeResolved(escrowId, releasedToSeller);
    }

    receive() external payable {
        revert Escrow__useCreateEscrow();
    }

    fallback() external payable {
        revert Escrow__useCreateEscrow();
    }

    /**
     *         GETTERS
     */

    function getEscrow(uint256 escrowId) public view escrowExist(escrowId) returns (Escrow memory) {
        return escrows[escrowId];
    }
}
