// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

contract MultiSigWallet {

    // =============================================================
    //                            ERRORS
    // =============================================================

    error MUST_BE_THREE_ADDRESSES();
    error ALREADY_EXECUTED();
    error ALREADY_CONFIRMED();
    error NOT_CONFIRMED();
    error NOT_ENOUGHT_CONFIRMATIONS();
    error REENTRANCY_GUARD();
    error INVALID_SIGNER();
    error SIGNER_ALREADY_EXISTS();
    error SIGNER_NOT_FOUND();
    error MINIMUM_SIGNERS_REQUIRED();

    // =============================================================
    //                          STATE VARIABLES
    // =============================================================

    address[] public signers;
    uint public required;
    uint private _reentrancyGuard;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public isConfirmed;
    mapping(address => bool) public isSignerMap; // Pour éviter les doublons

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    modifier onlySigner() {
        if (!isSigner(msg.sender)) revert INVALID_SIGNER();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyGuard != 0) revert REENTRANCY_GUARD();
        _reentrancyGuard = 1;
        _;
        _reentrancyGuard = 0;
    }

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(address[] memory _signers) {
        if(_signers.length != 3) revert MUST_BE_THREE_ADDRESSES();
        
        for (uint i = 0; i < _signers.length; i++) {
            if (_signers[i] == address(0)) revert INVALID_SIGNER();
            if (isSignerMap[_signers[i]]) revert SIGNER_ALREADY_EXISTS();
            isSignerMap[_signers[i]] = true;
        }
        
        signers = _signers;
        required = 2;
    }

    // =============================================================
    //                          PUBLIC FUNCTIONS
    // =============================================================

    function isSigner(address addr) public view returns (bool) {
        return isSignerMap[addr];
    }

    function submitTransaction(address to, uint value, bytes memory data) public onlySigner {
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            numConfirmations: 0
        }));
    }

    function confirmTransaction(uint txIndex) public onlySigner nonReentrant {
        if (isConfirmed[txIndex][msg.sender]) revert ALREADY_CONFIRMED();
        if (transactions[txIndex].executed) revert ALREADY_EXECUTED();

        isConfirmed[txIndex][msg.sender] = true;
        transactions[txIndex].numConfirmations += 1;

        if(transactions[txIndex].numConfirmations >= required) {
            executeTransaction(txIndex);
        }
    }

    function revokeConfirmation(uint txIndex) public onlySigner {
        if (!isConfirmed[txIndex][msg.sender]) revert NOT_CONFIRMED();
        if (transactions[txIndex].executed) revert ALREADY_EXECUTED();

        isConfirmed[txIndex][msg.sender] = false;
        transactions[txIndex].numConfirmations -= 1;
    }

    // =============================================================
    //                          PRIVATE FUNCTION
    // =============================================================

    function executeTransaction(uint txIndex) private nonReentrant {
        Transaction storage txn = transactions[txIndex];
        if (txn.executed) revert ALREADY_EXECUTED();
        if (txn.numConfirmations < required) revert NOT_ENOUGHT_CONFIRMATIONS();

        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Tx failed");
    }

    receive() external payable {}
}