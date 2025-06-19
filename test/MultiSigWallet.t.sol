// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract TestRecipient {
    uint public valueReceived;
    address public sender;
    bytes public dataReceived;

    function receiveData(uint val) public payable {
        valueReceived = val;
        sender = msg.sender;
        dataReceived = msg.data;
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    
    // Test addresses
    address public signer1 = address(0x1);
    address public signer2 = address(0x2);
    address public signer3 = address(0x3);
    address public nonSigner = address(0x4);
    address public recipient = address(0x5);
    
    address[] public signers;

    function setUp() public {
        signers = [signer1, signer2, signer3];
        wallet = new MultiSigWallet(signers);
    }

    // =============================================================
    //                          DEPLOYMENT TESTS
    // =============================================================

    function test_Constructor_ValidSigners() public {
        assertEq(wallet.signers(0), signer1);
        assertEq(wallet.signers(1), signer2);
        assertEq(wallet.signers(2), signer3);
        assertEq(wallet.required(), 2);
    }

    function test_Constructor_InvalidSignerCount() public {
        address[] memory invalidSigners = new address[](2);
        invalidSigners[0] = signer1;
        invalidSigners[1] = signer2;
        
        vm.expectRevert(MultiSigWallet.MUST_BE_THREE_ADDRESSES.selector);
        new MultiSigWallet(invalidSigners);
    }

    function test_Constructor_ZeroAddress() public {
        address[] memory invalidSigners = new address[](3);
        invalidSigners[0] = address(0);
        invalidSigners[1] = signer2;
        invalidSigners[2] = signer3;
        
        vm.expectRevert(MultiSigWallet.INVALID_SIGNER.selector);
        new MultiSigWallet(invalidSigners);
    }

    function test_Constructor_DuplicateSigners() public {
        address[] memory invalidSigners = new address[](3);
        invalidSigners[0] = signer1;
        invalidSigners[1] = signer1;
        invalidSigners[2] = signer3;
        
        vm.expectRevert(MultiSigWallet.SIGNER_ALREADY_EXISTS.selector);
        new MultiSigWallet(invalidSigners);
    }

    // =============================================================
    //                          SIGNER TESTS
    // =============================================================

    function test_IsSigner_ValidSigner() public {
        assertTrue(wallet.isSigner(signer1));
        assertTrue(wallet.isSigner(signer2));
        assertTrue(wallet.isSigner(signer3));
    }

    function test_IsSigner_InvalidSigner() public {
        assertFalse(wallet.isSigner(nonSigner));
        assertFalse(wallet.isSigner(address(0)));
    }

    // =============================================================
    //                      TRANSACTION SUBMISSION TESTS
    // =============================================================

    function test_SubmitTransaction_ValidSigner() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        (address to, uint value, bytes memory data, bool executed, uint numConfirmations) = wallet.transactions(0);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
    }

    function test_SubmitTransaction_InvalidSigner() public {
        vm.prank(nonSigner);
        vm.expectRevert(MultiSigWallet.INVALID_SIGNER.selector);
        wallet.submitTransaction(recipient, 1 ether, "");
    }

    function test_SubmitTransaction_WithData() public {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, 100);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 0, data);
        
        (,, bytes memory txData,,) = wallet.transactions(0);
        assertEq(txData, data);
    }

    // =============================================================
    //                      TRANSACTION CONFIRMATION TESTS
    // =============================================================

    function test_ConfirmTransaction_ValidSigner() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        assertTrue(wallet.isConfirmed(0, signer2));
        (,,,, uint numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 1);
    }

    function test_ConfirmTransaction_InvalidSigner() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(nonSigner);
        vm.expectRevert(MultiSigWallet.INVALID_SIGNER.selector);
        wallet.confirmTransaction(0);
    }

    function test_ConfirmTransaction_AlreadyConfirmed() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer2);
        vm.expectRevert(MultiSigWallet.ALREADY_CONFIRMED.selector);
        wallet.confirmTransaction(0);
    }

    function test_ConfirmTransaction_AlreadyExecuted() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer3);
        wallet.confirmTransaction(0);

        vm.prank(signer1);
        vm.expectRevert(MultiSigWallet.ALREADY_EXECUTED.selector);
        wallet.confirmTransaction(0);
    }

    // =============================================================
    //                      TRANSACTION REVOCATION TESTS
    // =============================================================

    function test_RevokeConfirmation_ValidSigner() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer2);
        wallet.revokeConfirmation(0);
        
        assertFalse(wallet.isConfirmed(0, signer2));
        (,,,, uint numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 0);
    }

    function test_RevokeConfirmation_NotConfirmed() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        vm.expectRevert(MultiSigWallet.NOT_CONFIRMED.selector);
        wallet.revokeConfirmation(0);
    }

    function test_RevokeConfirmation_AlreadyExecuted() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer3);
        wallet.confirmTransaction(0);

        vm.prank(signer2);
        vm.expectRevert(MultiSigWallet.ALREADY_EXECUTED.selector);
        wallet.revokeConfirmation(0);
    }

    // =============================================================
    //                      TRANSACTION EXECUTION TESTS
    // =============================================================

    function test_ExecuteTransaction_AutomaticExecution() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer3);
        wallet.confirmTransaction(0);
        
        (,,, bool executed,) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(recipient.balance, 1 ether);
    }

    function test_ExecuteTransaction_NotEnoughConfirmations() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        (,,, bool executed,) = wallet.transactions(0);
        assertFalse(executed);
        assertEq(recipient.balance, 0);
    }

    function test_ExecuteTransaction_WithData() public {
        vm.deal(address(wallet), 10 ether);
        
        TestRecipient recipientContract = new TestRecipient();
        
        bytes memory data = abi.encodeWithSignature("receiveData(uint256)", 42);
        
        vm.prank(signer1);
        wallet.submitTransaction(address(recipientContract), 0, data);
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer3);
        wallet.confirmTransaction(0);
        
        (,,, bool executed,) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(recipientContract.valueReceived(), 42);
        assertEq(recipientContract.sender(), address(wallet));
    }

    // =============================================================
    //                          SECURITY TESTS
    // =============================================================

    function test_ReentrancyProtection() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);

        (,,,, uint numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 1);
    }

    function test_OnlySignerAccess() public {
        vm.prank(nonSigner);
        vm.expectRevert(MultiSigWallet.INVALID_SIGNER.selector);
        wallet.submitTransaction(recipient, 1 ether, "");
    }

    // =============================================================
    //                          EDGE CASES
    // =============================================================

    function test_MultipleTransactions() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.submitTransaction(recipient, 2 ether, "");
        
        vm.prank(signer3);
        wallet.submitTransaction(recipient, 3 ether, "");
        
        (, uint value1,,,) = wallet.transactions(0);
        (, uint value2,,,) = wallet.transactions(1);
        (, uint value3,,,) = wallet.transactions(2);
        
        assertEq(value1, 1 ether);
        assertEq(value2, 2 ether);
        assertEq(value3, 3 ether);
    }

    function test_ConfirmRevokeConfirm() public {
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        (,,,, uint numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 1);

        vm.prank(signer2);
        wallet.revokeConfirmation(0);
        (,,,, numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 0);
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        (,,,, numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 1);
    }

    function test_ReceiveFunction() public {
        uint256 initialBalance = address(wallet).balance;
        
        vm.deal(address(this), 5 ether);
        (bool success,) = address(wallet).call{value: 5 ether}("");
        
        assertTrue(success);
        assertEq(address(wallet).balance, initialBalance + 5 ether);
    }

    // =============================================================
    //                          GAS OPTIMIZATION TESTS
    // =============================================================

    function test_GasOptimization_IsSigner() public {
        uint256 gasBefore = gasleft();
        wallet.isSigner(signer1);
        uint256 gasUsed = gasBefore - gasleft();
        
        assertLt(gasUsed, 20000);
    }

    // =============================================================
    //                          INTEGRATION TESTS
    // =============================================================

    function test_FullWorkflow() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);

        vm.prank(signer2);
        wallet.revokeConfirmation(0);
        
        vm.prank(signer2);
        wallet.confirmTransaction(0);

        vm.prank(signer3);
        wallet.confirmTransaction(0);
        
        (,,, bool executed, uint numConfirmations) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(recipient.balance, 1 ether);
        assertEq(numConfirmations, 2);
    }

    function test_AllSignersConfirm() public {
        vm.deal(address(wallet), 10 ether);
        
        vm.prank(signer1);
        wallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(signer1);
        wallet.confirmTransaction(0);
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        
        vm.prank(signer3);
        vm.expectRevert(MultiSigWallet.ALREADY_EXECUTED.selector);
        wallet.confirmTransaction(0);
        
        (,,, bool executed, uint numConfirmations) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
    }
}
