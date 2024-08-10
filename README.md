# Janction Points Contract

## Overview

The Janction Points Contract is a Solidity smart contract that allows the management and tracking of points associated with Ethereum addresses. The contract is controlled by an owner who can set points for individual or multiple accounts.

## Features

- **Update Points**: The contract owner can set the points associated with a specific Ethereum address.
- **Batch Update Points**: The contract owner can set points for multiple Ethereum addresses in a single transaction.
- **Get Points**: Public function to retrieve the current points associated with any Ethereum address.

## Requirements

- **Solidity**: ^0.8.21
- **OpenZeppelin Contracts**: Utilizes the Ownable module to manage owner-specific functionalities.

## Test

To test the contract using Foundry, execute the following command:

```bash
forge test
```

## Deployment

To deploy the contract, follow these steps:

Create a `.env` file in your project directory and add your Ethereum RPC URL and private key:

```bash
PRIVATE_KEY=your_private_key_here
```

Deploy the contract with the following command:

```bash
source .env && forge script script/DeployPoints.s.sol --rpc-url op_sepolia --private-key $PRIVATE_KEY --broadcast
```
