// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletScript is Script {
    MultiSigWallet public wallet;

    address[] public signers = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906
    ];

    function setUp() public {
        require(signers.length == 3, "Must have exactly 3 signers");
        
        for (uint i = 0; i < signers.length; i++) {
            require(signers[i] != address(0), "Signer cannot be zero address");
            for (uint j = i + 1; j < signers.length; j++) {
                require(signers[i] != signers[j], "Duplicate signer detected");
            }
        }
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Deploying MultiSig Wallet...");
        console.log("Configuration:");
        console.log("   - Required confirmations: 2");
        console.log("   - Total signers: 3");
        
        for (uint i = 0; i < signers.length; i++) {
            console.log("   - Signer %d: %s", i + 1, signers[i]);
        }
        
        console.log("");
        console.log("Deployer address: %s", vm.addr(deployerPrivateKey));
        console.log("Gas price: %s gwei", block.basefee / 1e9);
        
        vm.startBroadcast(deployerPrivateKey);

        wallet = new MultiSigWallet(signers);

        vm.stopBroadcast();

        console.log("");
        console.log("MultiSig Wallet deployed successfully!");
        console.log("Contract address: %s", address(wallet));
        console.log("");
        console.log("Verification:");
        console.log("   - Required confirmations: %d", wallet.required());
        console.log("   - Signer 1: %s", wallet.signers(0));
        console.log("   - Signer 2: %s", wallet.signers(1));
        console.log("   - Signer 3: %s", wallet.signers(2));
        console.log("");
        console.log("Next steps:");
        console.log("   1. Verify the contract on Etherscan");
        console.log("   2. Test the wallet with small amounts first");
        console.log("   3. Fund the wallet with ETH");
        console.log("   4. Test transaction submission and confirmation");
    }

    function deployWithCustomSigners(address[] memory _signers) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Deploying MultiSig Wallet with custom signers...");
        
        vm.startBroadcast(deployerPrivateKey);
        wallet = new MultiSigWallet(_signers);
        vm.stopBroadcast();
        
        console.log("MultiSig Wallet deployed at: %s", address(wallet));
    }

    function verifyDeployment() public view {
        console.log("Verifying deployment...");
        console.log("Contract address: %s", address(wallet));
        console.log("Required confirmations: %d", wallet.required());
        
        for (uint i = 0; i < 3; i++) {
            address signer = wallet.signers(i);
            bool isValidSigner = wallet.isSigner(signer);
            console.log("Signer %d: %s (Valid: %s)", i + 1, signer, isValidSigner ? "Yes" : "No");
        }
    }
}