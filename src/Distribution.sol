// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Distribution is Ownable {
    using SafeERC20 for IERC20;

    event Distributed(
        address indexed payer,
        address indexed treasury,
        address indexed currency,
        uint256 totalAmount,
        uint256 remainingAmount,
        address[] beneficiaries,
        uint256[] rewards
    );

    address public treasury;
    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    constructor(address initialOwner, address initialTreasury) Ownable(initialOwner) {
        treasury = initialTreasury;
    }

    function whitelistCurrency(
        address currency,
        bool status
    ) external onlyOwner {
        isCurrencyWhitelisted[currency] = status;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
    }

    function distribute(
        address currency,
        uint256 totalAmount,
        address[] memory beneficiaries,
        uint256[] memory rewards
    ) external {
        require(
            beneficiaries.length == rewards.length,
            "array length not equal"
        );
        require(isCurrencyWhitelisted[currency], "currency not whitelisted");

        uint256 remainingAmount = totalAmount;
        for (uint256 i = 0; i < beneficiaries.length; ++i) {
            IERC20(currency).safeTransferFrom(
                msg.sender,
                beneficiaries[i],
                rewards[i]
            );
            remainingAmount -= rewards[i];
        }

        IERC20(currency).safeTransferFrom(
            msg.sender,
            treasury,
            remainingAmount
        );

        emit Distributed(
            msg.sender,
            treasury,
            currency,
            totalAmount,
            remainingAmount,
            beneficiaries,
            rewards
        );
    }
}
