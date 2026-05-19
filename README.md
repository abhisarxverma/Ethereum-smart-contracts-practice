# 🛠️ Ethereum Smart Contract Practice

A collection of beginner-to-intermediate Solidity smart contracts built while learning blockchain development, smart contract architecture, and testing with Foundry 🚀

This repository is my personal smart contract practice ground where I focus on:

* Understanding how blockchain systems actually work
* Writing clean Solidity code
* Learning smart contract design patterns
* Building secure contract logic
* Writing proper tests using Foundry
* Thinking through real-world use cases instead of just copying tutorials

---

# 📚 Contracts Included

## 🏦 Minimal Bank

A very small banking-style contract for learning ETH deposits and withdrawals.

### Features

* Deposit ETH into the contract
* Withdraw ETH
* Track user balances
* Basic balance management logic

### Purpose

Built to understand:

* `msg.sender`
* `msg.value`
* mappings
* ETH transfers
* contract balances

---

## 🔐 MultiSig Wallet

A wallet that requires multiple owners to approve transactions before execution.

### Features

* Multiple wallet owners
* Submit transactions
* Approve transactions
* Revoke approvals
* Execute only after enough confirmations

### Purpose

Built to understand:

* multi-party authorization
* transaction approval systems
* nested mappings
* access control
* governance-style logic

---

## 💰 Savings Vault

A simple vault contract for storing ETH safely with custom withdrawal logic.

### Features

* Deposit ETH
* Store balances securely
* Controlled withdrawals
* Vault-style accounting

### Purpose

Built to practice:

* state management
* user balances
* payable functions
* secure ETH handling

---

## 🤝 Escrow Contract

A trust-minimized escrow system between buyer and seller with dispute resolution.

### Features

* Buyer locks ETH into escrow
* Seller receives payment after delivery confirmation
* Refund support
* Arbiter-based dispute resolution

### Purpose

Built to understand:

* real-world transaction flows
* escrow mechanics
* dispute handling
* state machines in Solidity

---

## 🗳️ DAO Voting System

A simple governance contract where users can create proposals and vote on them.

### Features

* Create proposals
* Vote YES/NO
* Execute passed proposals
* DAO treasury funding support

### Purpose

Built to understand:

* DAO mechanics
* proposal lifecycle
* voting systems
* on-chain governance logic

---

# 🧪 Testing

All contracts are tested using **Foundry** ⚒️

Testing includes:

* Unit tests
* Edge cases
* Revert testing
* Event testing
* ETH transfer testing
* Multi-user simulations

---

# 🛠️ Tech Stack

* Solidity `^0.8.x`
* Foundry
* Forge Std Library

---

# 🎯 Goal of This Repository

This repo is part of my journey toward becoming a strong **Smart Contract / Full Stack Web3 Developer** 🌐

The focus is not just building projects, but understanding:

* why systems are designed a certain way
* how smart contracts manage trust
* how blockchain applications work internally
* how to write safer and cleaner Solidity

---

# 🚀 Future Plans

More advanced projects coming soon:

* ERC20 tokens
* NFT systems
* Advanced DAO governance
* DeFi protocols
* Staking systems
* Security-focused contracts
* Full stack dApps with Next.js + Solidity

---

# 📌 Note

These contracts are built for learning and practice purposes.
They are **not audited** and should not be used in production environments.

---

Thanks for checking out the repo 🙌
