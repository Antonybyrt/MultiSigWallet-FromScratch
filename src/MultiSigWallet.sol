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
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when a new transaction is submitted
     * @param txIndex The index of the transaction
     * @param submitter The address that submitted the transaction
     * @param to The recipient address
     * @param value The amount of ETH to send
     * @param data The transaction data
     */
    event TransactionSubmitted(
        uint indexed txIndex,
        address indexed submitter,
        address indexed to,
        uint value,
        bytes data
    );

    /**
     * @notice Emitted when a transaction is confirmed by a signer
     * @param txIndex The index of the transaction
     * @param signer The address that confirmed the transaction
     */
    event TransactionConfirmed(
        uint indexed txIndex,
        address indexed signer
    );

    /**
     * @notice Emitted when a transaction confirmation is revoked
     * @param txIndex The index of the transaction
     * @param signer The address that revoked the confirmation
     */
    event ConfirmationRevoked(
        uint indexed txIndex,
        address indexed signer
    );

    /**
     * @notice Emitted when a transaction is executed
     * @param txIndex The index of the transaction
     * @param to The recipient address
     * @param value The amount of ETH sent
     * @param data The transaction data
     */
    event TransactionExecuted(
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );

    /**
     * @notice Emitted when ETH is received by the wallet
     * @param sender The address that sent ETH
     * @param amount The amount of ETH received
     */
    event ETHReceived(
        address indexed sender,
        uint amount
    );

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

    /**
     * @notice Structure representing a transaction
     * @param to The recipient address
     * @param value The amount of ETH to send
     * @param data The transaction data
     * @param executed Whether the transaction has been executed
     * @param numConfirmations The number of confirmations received
     */
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

    /**
     * @notice Restricts function access to signers only
     */
    modifier onlySigner() {
        if (!isSigner(msg.sender)) revert INVALID_SIGNER();
        _;
    }

    /**
     * @notice Prevents reentrancy attacks
     */
    modifier nonReentrant() {
        if (_reentrancyGuard != 0) revert REENTRANCY_GUARD();
        _reentrancyGuard = 1;
        _;
        _reentrancyGuard = 0;
    }

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @notice Initializes the multisig wallet with 3 signers
     * @param _signers Array of 3 signer addresses
     * @dev Requires exactly 3 unique, non-zero addresses
     */
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

    /**
     * @notice Checks if an address is a signer
     * @param addr The address to check
     * @return True if the address is a signer, false otherwise
     */
    function isSigner(address addr) public view returns (bool) {
        return isSignerMap[addr];
    }

    /**
     * @notice Submits a new transaction for approval
     * @param to The recipient address
     * @param value The amount of ETH to send
     * @param data The transaction data
     * @dev Only signers can submit transactions
     */
    function submitTransaction(address to, uint value, bytes memory data) public onlySigner {
        uint txIndex = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            numConfirmations: 0
        }));

        emit TransactionSubmitted(txIndex, msg.sender, to, value, data);
    }

    /**
     * @notice Confirms a transaction by a signer
     * @param txIndex The index of the transaction to confirm
     * @dev Only signers can confirm transactions. If enough confirmations are reached, the transaction is executed automatically.
     */
    function confirmTransaction(uint txIndex) public onlySigner nonReentrant {
        if (isConfirmed[txIndex][msg.sender]) revert ALREADY_CONFIRMED();
        if (transactions[txIndex].executed) revert ALREADY_EXECUTED();

        isConfirmed[txIndex][msg.sender] = true;
        transactions[txIndex].numConfirmations += 1;

        emit TransactionConfirmed(txIndex, msg.sender);

        if(transactions[txIndex].numConfirmations >= required) {
            executeTransaction(txIndex);
        }
    }

    /**
     * @notice Revokes a confirmation for a transaction
     * @param txIndex The index of the transaction to revoke confirmation for
     * @dev Only signers can revoke their own confirmations
     */
    function revokeConfirmation(uint txIndex) public onlySigner {
        if (!isConfirmed[txIndex][msg.sender]) revert NOT_CONFIRMED();
        if (transactions[txIndex].executed) revert ALREADY_EXECUTED();

        isConfirmed[txIndex][msg.sender] = false;
        transactions[txIndex].numConfirmations -= 1;

        emit ConfirmationRevoked(txIndex, msg.sender);
    }

    // =============================================================
    //                          PRIVATE FUNCTION
    // =============================================================

    /**
     * @notice Executes a transaction when enough confirmations are received
     * @param txIndex The index of the transaction to execute
     * @dev This function is called automatically when the required number of confirmations is reached
     */
    function executeTransaction(uint txIndex) private {
        Transaction storage txn = transactions[txIndex];
        if (txn.executed) revert ALREADY_EXECUTED();
        if (txn.numConfirmations < required) revert NOT_ENOUGHT_CONFIRMATIONS();

        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Tx failed");

        emit TransactionExecuted(txIndex, txn.to, txn.value, txn.data);
    }

    // =============================================================
    //                          FALLBACK FUNCTION
    // =============================================================

    /**
     * @notice Allows the wallet to receive ETH
     * @dev Emits ETHReceived event when ETH is received
     */
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
}