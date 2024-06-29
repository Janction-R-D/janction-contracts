# Janction Score Contract

## Overview

The Foundry Score smart contract allows for incrementing scores associated with Ethereum addresses. This contract is designed to be owned by an administrator (owner) who can manage scores across multiple accounts.

## Features

- **Increment Score**: The owner can increase the score of a specific account.
- **Batch Increment Score**: The owner can increase scores for multiple accounts in a single transaction.
- **Get Score**: Retrieve the current score of any account.

## Requirements

Solidity ^0.8.21
OpenZeppelin Contracts (Ownable)

## Test
```bash
forge test
```

## Deployment

First, create the **.env** file and add your Ethereum RPC URL and private key.
Then,
```bash
source .env && forge script script/DeployScore.s.sol --rpc-url op_sepolia --private-key $PRIVATE_KEY --broadcast
```
