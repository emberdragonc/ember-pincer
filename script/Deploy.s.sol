// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Pincer.sol";

contract DeployPincer is Script {
    // EMBER Staking contract on Base (receives protocol fees)
    address constant EMBER_STAKING_MAINNET = 0x434B2A0e38FB3E5D2ACFa2a7aE492C2A53E55Ec9;

    // For testnet, we'll use a test fee recipient
    address constant FEE_RECIPIENT_TESTNET = 0xE3c938c71273bFFf7DEe21BDD3a8ee1e453Bdd1b; // Ember wallet

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("EMBER_WALLET_KEY");

        // Determine fee recipient based on chain
        address feeRecipient;
        if (block.chainid == 8453) {
            // Base Mainnet
            feeRecipient = EMBER_STAKING_MAINNET;
            console.log("Deploying to Base Mainnet");
        } else {
            // Testnet
            feeRecipient = FEE_RECIPIENT_TESTNET;
            console.log("Deploying to Testnet");
        }

        vm.startBroadcast(deployerPrivateKey);

        Pincer pincer = new Pincer(feeRecipient);

        console.log("Pincer deployed at:", address(pincer));
        console.log("Fee recipient:", feeRecipient);
        console.log("Protocol fee: 2%");

        vm.stopBroadcast();
    }
}
