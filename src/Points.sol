// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Points is Ownable {
    error ArrayLengthMustBeEqual();

    event PointsUpdated(address indexed account, uint256 indexed points);

    mapping(address => uint256) internal _points;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function updatePoints(address account, uint256 points) public onlyOwner {
        _points[account] = points;
        emit PointsUpdated(account, points);
    }

    function batchUpdatePoints(
        address[] calldata accountList,
        uint256[] calldata pointsList
    ) public onlyOwner {
        if (accountList.length != pointsList.length) {
            revert ArrayLengthMustBeEqual();
        }
        for (uint256 i = 0; i < accountList.length; ++i) {
            _points[accountList[i]] = pointsList[i];
            emit PointsUpdated(accountList[i], pointsList[i]);
        }
    }

    function getPointsBy(address account) public view returns (uint256) {
        return _points[account];
    }
}
