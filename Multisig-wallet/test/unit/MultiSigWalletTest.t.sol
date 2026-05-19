// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../../src/MultiSigWallet.sol";

contract TestMultiSigWallet is Test {
    MultiSigWallet multiSigWallet;

    address owner1;
    address owner2;
    address owner3;
    address nonOwner = makeAddr("non-owner");
    address toAddr = makeAddr("to-address");

    address[] owners;

    uint256 constant REQUIRED_APPROVALS = 2;
    uint256 constant CONTRACT_STARTING_BALANCE = 10 ether;

    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Funded(uint256 amount);

    function setUp() external {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");

        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        multiSigWallet = new MultiSigWallet(owners, REQUIRED_APPROVALS);

        vm.deal(address(multiSigWallet), CONTRACT_STARTING_BALANCE);
    }

    /**
     *         DEPLOYER CONSTRUCTOR
     */

    function testDeployWithValidOwnerWorks() public view {
        assertEq(multiSigWallet.getOwners()[0], owner1);
        assertEq(multiSigWallet.getOwners()[1], owner2);
        assertEq(multiSigWallet.getOwners()[2], owner3);
    }

    function testDeployWithDuplicateOwnerReverts() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");

        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner1;
        owners[2] = owner2;

        vm.expectRevert(MultiSigWallet.MultiSigWallet__duplicateOwner.selector);
        multiSigWallet = new MultiSigWallet(owners, REQUIRED_APPROVALS);
    }

    function testDeployWithZeroAddressReverts() public {
        owners = new address[](2);
        owners[0] = address(0);
        owners[1] = makeAddr("owner2");

        vm.expectRevert(MultiSigWallet.MultiSigWallet__invalidOwnerAddress.selector);
        multiSigWallet = new MultiSigWallet(owners, REQUIRED_APPROVALS);
    }

    function testDeployWithZeroApprovalsReverts() public {
        owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert(MultiSigWallet.MultiSigWallet__invalidRequiredApprovals.selector);
        new MultiSigWallet(owners, 0);
    }

    function testDeployWithTooManyApprovalsReverts() public {
        owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert(MultiSigWallet.MultiSigWallet__invalidRequiredApprovals.selector);
        new MultiSigWallet(owners, 3);
    }

    function testConstructorSetsRequiredApprovalsCorrectly() public view {
        assertEq(multiSigWallet.requiredApprovals(), REQUIRED_APPROVALS);
    }

    /**
                SUBMIT TRANSACTION
     */

    function testOwnerCanSubmit() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.5 ether, "");
        assertEq(multiSigWallet.getTransaction(0).to, toAddr);
        assertEq(multiSigWallet.getTransaction(0).value, 0.5 ether);
        assertEq(multiSigWallet.getTransaction(0).data, "");
    }

    function testSubmitByNonOwnerReverts() public {
        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__notOwner.selector);
        multiSigWallet.submitTransaction(toAddr, 0.5 ether, "");
    }

    function testSubmitTransactionEmitsEvent() public {
        vm.prank(owner1);
        vm.expectEmit(true, false, false, false, address(multiSigWallet));
        emit Submit(0);
        multiSigWallet.submitTransaction(toAddr, 0.5 ether, "");
    }

    function testSubmitTransactionFailsForAddressZero() public {
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__invalidAddressToTransact.selector);
        multiSigWallet.submitTransaction(address(0), 0.5 ether, "");
    }

    function testIdsIncrementCorrectlyForMultipleSubmissions() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.5 ether, "");
        vm.prank(owner2);
        multiSigWallet.submitTransaction(toAddr, 0.7 ether, "");

        assertEq(multiSigWallet.getTransaction(0).value, 0.5 ether);
        assertEq(multiSigWallet.getTransaction(0).to, toAddr);
        assertEq(multiSigWallet.getTransaction(1).value, 0.7 ether);
        assertEq(multiSigWallet.getTransaction(1).to, toAddr);
    }

    /**
                APPROVE TRANSACTION
     */

    function testApprovedByOwnerWorks() public {
        // Arrange
        vm.prank(owner2);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act
        vm.prank(owner1);
        multiSigWallet.approveTransaction(0);

        // Assert
        assertEq(multiSigWallet.getTransaction(0).numberOfApprovals, 1);
        assertEq(multiSigWallet.getApproved(0, owner1), true);
    }

    function testApprovedByNonOwnerReverts() public {
        // Arrange
        vm.prank(owner2);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act / Assert
        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__notOwner.selector);
        multiSigWallet.approveTransaction(0);
    }

    function testSameOwnerApprovesTwiceReverts() public {
        // Arrange
        vm.prank(owner2);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act / Assert
        vm.startPrank(owner3);
        multiSigWallet.approveTransaction(0);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__alreadyApproved.selector);
        multiSigWallet.approveTransaction(0);
    }

    function testApproveTransactionEmitsEvent() public {
        // Arrange
        vm.prank(owner2);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act / Assert
        vm.prank(owner1);
        vm.expectEmit(true, true, false, false, address(multiSigWallet));
        emit Approve(owner1, 0);
        multiSigWallet.approveTransaction(0);
    }

    /**
                EXECUTE TRANSACTION
     */

    function testExecuteWorksForEnoughApprovals() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);

        uint256 startingBalance = address(multiSigWallet).balance;

        // Act
        vm.prank(owner3);
        multiSigWallet.executeTransaction(0);

        // Assert
        assertEq(multiSigWallet.getTransaction(0).numberOfApprovals, 2);
        assertEq(multiSigWallet.getTransaction(0).executed, true);
        assertEq(multiSigWallet.getApproved(0, owner3), true);
        assertEq(multiSigWallet.getApproved(0, owner2), true);
        assertEq(address(multiSigWallet).balance, startingBalance - 0.05 ether);
        assertEq(toAddr.balance, 0.05 ether);
    }

    function testExecuteForNoEnoughApprovalsReverts() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);

        // Act
        vm.prank(owner3);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__approvalsNotSufficientToExecute.selector);
        multiSigWallet.executeTransaction(0);
    }
    
    function testExecuteForAlreadyExecutedReverts() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.executeTransaction(0);


        // Act / Assert
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__alreadyExecuted.selector);
        multiSigWallet.executeTransaction(0);        
    }

    function testExecuteTransactionEmitsEvent() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);

        // Act / Assert
        vm.prank(owner3);
        vm.expectEmit(true, false, false, false, address(multiSigWallet));
        emit Execute(0);
        multiSigWallet.executeTransaction(0);
    }

    function testExecuteWithInsufficientContractBalanceReverts() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 11 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);

        // Act / Assert
        vm.prank(owner3);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__insufficientFundsToExecuteTransaction.selector);
        multiSigWallet.executeTransaction(0);
    }

    /**
            REVOKE TRANSACTION  
     */

    function testApprovedUserCanRevokeWorks() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);

        // Act
        vm.prank(owner2);
        multiSigWallet.revokeApproval(0);

        // Assert
        assertEq(multiSigWallet.getTransaction(0).numberOfApprovals, 0);
        assertEq(multiSigWallet.getApproved(0, owner2), false);
    }

    function testRevokeForNotApprovedReverts() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act / Assert
        vm.prank(owner2);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__alreadyNotApproved.selector);
        multiSigWallet.revokeApproval(0);
    }

    function testRevokeEmitsEvent() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);

        vm.prank(owner2);
        vm.expectEmit(true, true, false, false, address(multiSigWallet));
        emit Revoke(owner2, 0);
        multiSigWallet.revokeApproval(0);
    }

    /**
            MULTI USERS 
     */

    function testMultipleUsersApproveSameTransactionWorks() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);

        // Assert
        assertEq(multiSigWallet.getTransaction(0).numberOfApprovals, 2);
        assertEq(multiSigWallet.getApproved(0, owner2), true);
        assertEq(multiSigWallet.getApproved(0, owner3), true);
    }

    function testApprovalsCountCorrectly() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");

        // Act
        vm.prank(owner1);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);

        // Assert
        assertEq(multiSigWallet.getTransaction(0).numberOfApprovals, 3);
        assertEq(multiSigWallet.getApproved(0, owner1), true);
        assertEq(multiSigWallet.getApproved(0, owner2), true);
        assertEq(multiSigWallet.getApproved(0, owner3), true);
    }

    /**
            ETH TRANSFERS
     */

    function testContractReceivesEthAndEmitsEvent() public {
        // Act
        vm.expectEmit(false, false, false, true, address(multiSigWallet));
        emit Funded(1 ether);
        (bool success, ) = address(multiSigWallet).call{value: 1 ether}("");
        assert(success == true);
        assertEq(address(multiSigWallet).balance, CONTRACT_STARTING_BALANCE + 1 ether);
    }

    function testEthTransfersDuringExecution() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);

        uint256 startingBalance = address(multiSigWallet).balance;

        // Act
        vm.prank(owner3);
        multiSigWallet.executeTransaction(0);

        // Assert
        assertEq(address(multiSigWallet).balance, startingBalance - 0.05 ether);
        assertEq(toAddr.balance, 0.05 ether);
    }

    /**
            AFTER EXECUTION
     */

    function testApproveAfterExecutedReverts() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.executeTransaction(0);

        // Act / Assert
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__alreadyExecuted.selector);
        multiSigWallet.approveTransaction(0);
    }

    function testRevokeAfterExecutedReverts() public {
        // Arrange
        vm.prank(owner1);
        multiSigWallet.submitTransaction(toAddr, 0.05 ether, "");
        vm.prank(owner2);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.approveTransaction(0);
        vm.prank(owner3);
        multiSigWallet.executeTransaction(0);

        // Act / Assert
        vm.prank(owner3);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__alreadyExecuted.selector);
        multiSigWallet.revokeApproval(0);
    }
}
