// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

contract ScoreContract {
    error ScoreMustBeGreaterThanZero();
    event ScoreSubmitted(uint256 indexed score, address indexed submitter);

    mapping(address => uint256) public scores;

    function submitScore(uint256 _score) public {
        if(_score == 0) {
            revert ScoreMustBeGreaterThanZero();
        }
        scores[msg.sender] = _score; 
        emit ScoreSubmitted(_score, msg.sender);
    }

    function getScore(address _address) public view returns (uint256) {
        return scores[_address];
    }
}