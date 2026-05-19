// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

contract Vault {
    error Vault__amountLowerThanMinimumDepositAmount();
    error Vault__depositIndexOutOfRange();
    error Vault__depositNotUnlocked();
    error Vault__withdrawFundTransferFailed();
    error Vault__useDeposit();

    uint256 public constant MINIMUM_DEPOSIT_AMOUNT = 0.05 ether;

    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => Deposit[]) public deposits;

    event Deposited(address indexed _address, uint256 indexed _amount, uint256 indexed _unlockTime);
    event Withdrawn(address indexed _address, uint256 indexed _amount);

    function deposit(uint256 durationInDays) public payable {
        if (durationInDays == 0) revert();
        if (msg.value < MINIMUM_DEPOSIT_AMOUNT) {
            revert Vault__amountLowerThanMinimumDepositAmount();
        }

        uint256 unlockTime = block.timestamp + (durationInDays * 1 days);

        deposits[msg.sender].push(Deposit(msg.value, unlockTime));

        emit Deposited(msg.sender, msg.value, unlockTime);
    }

    function withdraw(uint256 depositIndex) public {
        if (depositIndex >= deposits[msg.sender].length) {
            revert Vault__depositIndexOutOfRange();
        }

        if (deposits[msg.sender][depositIndex].unlockTime > block.timestamp) {
            revert Vault__depositNotUnlocked();
        }

        uint256 withdrawAmount = deposits[msg.sender][depositIndex].amount;
        uint256 lastIndex = deposits[msg.sender].length - 1;
        deposits[msg.sender][depositIndex] = deposits[msg.sender][lastIndex];
        deposits[msg.sender].pop();

        (bool success,) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, Vault__withdrawFundTransferFailed());

        emit Withdrawn(msg.sender, withdrawAmount);
    }

    function seeDeposit(address user, uint256 depositIndex) public view returns (Deposit memory) {
        if (depositIndex >= deposits[user].length) {
            revert Vault__depositIndexOutOfRange();
        }
        return deposits[user][depositIndex];
    }

    receive() external payable {
        revert Vault__useDeposit();
    }

    fallback() external payable {
        revert Vault__useDeposit();
    }
}
