// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

contract MultiSigWallet {
    error MultiSigWallet__invalidDepositAmount();
    error MultiSigWallet__insufficientFunds();
    error MultiSigWallet__notOwner();
    error MultiSigWallet__invalidTransactionId();
    error MultiSigWallet__alreadyExecuted();
    error MultiSigWallet__alreadyApproved();
    error MultiSigWallet__approvalsNotSufficientToExecute();
    error MultiSigWallet__ethTransferFailedDuringExecution();
    error MultiSigWallet__alreadyNotApproved();
    error MultiSigWallet__insufficientFundsToExecuteTransaction();
    error MultiSigWallet__emptyOwnersList();
    error MultiSigWallet__duplicateOwner();
    error MultiSigWallet__invalidOwnerAddress();
    error MultiSigWallet__invalidRequiredApprovals();
    error MultiSigWallet__invalidAddressToTransact();

    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public approved;
    address[] public owners;

    uint256 public requiredApprovals;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numberOfApprovals;
    }

    Transaction[] public transactions;

    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Funded(uint256 amount);

    constructor(address[] memory _owners, uint256 _requiredApprovals) {
        if (_owners.length == 0) revert MultiSigWallet__emptyOwnersList();
        if (_requiredApprovals == 0 || _requiredApprovals > _owners.length) {
            revert MultiSigWallet__invalidRequiredApprovals();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) revert MultiSigWallet__invalidOwnerAddress();
            if (isOwner[owner]) revert MultiSigWallet__duplicateOwner();

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredApprovals = _requiredApprovals;
    }

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert MultiSigWallet__notOwner();
        }
        _;
    }

    modifier transactionExist(uint256 txId) {
        if (txId >= transactions.length) {
            revert MultiSigWallet__invalidTransactionId();
        }
        _;
    }

    modifier transactionNotExecuted(uint256 txId) {
        if (transactions[txId].executed) {
            revert MultiSigWallet__alreadyExecuted();
        }
        _;
    }

    modifier notApproved(uint256 txId) {
        if (approved[txId][msg.sender]) revert MultiSigWallet__alreadyApproved();
        _;
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) public onlyOwner {
        if (to == address(0)) {
            revert MultiSigWallet__invalidAddressToTransact();
        }
        Transaction memory newTransaction =
            Transaction({to: to, value: value, data: data, executed: false, numberOfApprovals: 0});

        transactions.push(newTransaction);

        emit Submit(transactions.length - 1);
    }

    function approveTransaction(uint256 txId)
        public
        onlyOwner
        transactionExist(txId)
        transactionNotExecuted(txId)
        notApproved(txId)
    {
        approved[txId][msg.sender] = true;
        transactions[txId].numberOfApprovals += 1;

        emit Approve(msg.sender, txId);
    }

    function executeTransaction(uint256 txId) public onlyOwner transactionExist(txId) transactionNotExecuted(txId) {
        if (transactions[txId].numberOfApprovals < requiredApprovals) {
            revert MultiSigWallet__approvalsNotSufficientToExecute();
        }

        if (address(this).balance < transactions[txId].value) {
            revert MultiSigWallet__insufficientFundsToExecuteTransaction();
        }

        transactions[txId].executed = true;

        (bool success,) = payable(transactions[txId].to).call{value: transactions[txId].value}(transactions[txId].data);
        require(success, MultiSigWallet__ethTransferFailedDuringExecution());

        emit Execute(txId);
    }

    function revokeApproval(uint256 txId) public onlyOwner transactionExist(txId) transactionNotExecuted(txId) {
        if (!approved[txId][msg.sender]) {
            revert MultiSigWallet__alreadyNotApproved();
        }
        approved[txId][msg.sender] = false;
        transactions[txId].numberOfApprovals -= 1;

        emit Revoke(msg.sender, txId);
    }

    receive() external payable {
        if (msg.value > 0) {
            emit Funded(msg.value);
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            emit Funded(msg.value);
        }

    }

    /**
     *         GETTERS
     */

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 txId) public view transactionExist(txId) returns (Transaction memory) {
        return transactions[txId];
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getApproved(uint256 txId, address owner) transactionExist(txId) public view returns(bool) {
        return approved[txId][owner];
    }
}
