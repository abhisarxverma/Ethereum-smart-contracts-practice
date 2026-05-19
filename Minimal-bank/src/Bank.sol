// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

contract Bank {
    error Bank__depositAmountLowerThanMinimum();
    error Bank__insufficientBalance();
    error Bank__withdrawFailed();

    uint256 public constant MINIMUM_DEPOSIT_AMOUNT = 0.01 ether;

    mapping(address => uint256) balances;

    event Deposited(address indexed _address, uint256 indexed _amount);
    event Withdrawn(address indexed _address, uint256 indexed _amount);

    function deposit() public payable {
        // Checks
        if (msg.value < MINIMUM_DEPOSIT_AMOUNT) {
            revert Bank__depositAmountLowerThanMinimum();
        }

        // Effects
        balances[msg.sender] += msg.value;

        // Interaction
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        // Checks
        if (amount <= 0) revert();
        if (balances[msg.sender] < amount) {
            revert Bank__insufficientBalance();
        }

        // Effects
        balances[msg.sender] -= amount;

        // Interactions
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, Bank__withdrawFailed());
        emit Withdrawn(msg.sender, amount);
    }

    function balanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }
}
