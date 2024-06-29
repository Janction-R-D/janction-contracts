// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Score is Ownable {
    error ArrayLengthMustBeEqual();
    
    event ScoreIncremented(address indexed account, uint256 indexed increment);

    mapping(address => uint256) internal _scores;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function incrementScore(address account, uint256 increment) public onlyOwner {
        _scores[account] += increment;
        emit ScoreIncremented(account, increment);
    }

    function batchIncrementScore(address[] calldata accounts, uint256[] calldata increments) public onlyOwner {
        if(accounts.length != increments.length) {
            revert ArrayLengthMustBeEqual();
        }
        for(uint256 i = 0; i < accounts.length; ++i) {
            _scores[accounts[i]] += increments[i];
            emit ScoreIncremented(accounts[i], increments[i]);
        }
    }

    function getScore(address account) public view returns (uint256) {
        return _scores[account];
    }
}
