# MultiSig Wallet from Scratch

A secure multisignature wallet developed in Solidity without using external libraries.

## 🎯 Features

### Core Features
- **3 mandatory signers** with validation by at least 2 signers
- **Transaction submission** by any signer
- **Transaction validation and revocation** by signers
- **Automatic execution** when validation threshold is reached
- **Secure management** of signers (add/remove via special transactions)

## 🏗️ Architecture

### Contract Structure
```solidity
contract MultiSigWallet {
    address[] public signers;           // List of signers
    uint public required;               // Number of required validations (2)
    mapping(address => bool) public isSignerMap;  // O(1) verification
    
    struct Transaction {
        address to;                     // Recipient
        uint value;                     // Amount in ETH
        bytes data;                     // Transaction data
        bool executed;                  // Execution status
        uint numConfirmations;          // Number of validations
    }
}
```

### Workflow
1. **Submission** : A signer proposes a transaction
2. **Validation** : Other signers can validate/revoke
3. **Execution** : Transaction executed automatically when 2+ validations
4. **Management** : Add/remove signers via special transactions

## 🧪 Tests

### Coverage : 100% ✅

The project includes a comprehensive suite of unit tests covering:

- ✅ **Deployment** : Constructor and parameter validation
- ✅ **Submission** : Transaction creation by signers
- ✅ **Validation** : Transaction confirmation and revocation
- ✅ **Execution** : Automatic and manual execution
- ✅ **Security** : Protection against reentrancy and attacks
- ✅ **Error handling** : All possible error cases
- ✅ **Edge cases** : Edge cases and complex scenarios

### Run Tests
```bash
# Complete tests
forge test

# Tests with coverage
forge coverage

# Tests with gas report
forge test --gas-report
```

## 🚀 Deployment

### Prerequisites
- Foundry installed
- Private key with ETH for deployment

### Deployment
```bash
# Compile
forge build

# Deploy (replace addresses)
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```


## 🛡️ Security

### Implemented Measures
- **Reentrancy Guard** : Protection against reentrancy attacks
- **Access Control** : Only signers can interact
- **State Validation** : State verification before modification
- **Gas Optimization** : Using errors instead of require
- **Input Validation** : Strict parameter validation


## 📄 License

This project is licensed under AGPL-3.0. See the `LICENSE` file for more details.

---

**Developed with ❤️ in pure Solidity, without external libraries.**
