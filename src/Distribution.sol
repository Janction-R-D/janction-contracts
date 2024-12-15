// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Distribution is Ownable {
    using SafeERC20 for IERC20;

    event Distributed(
        address signer,
        address currency,
        address[] beneficiaries,
        uint256[] rewards
    );

    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function whitelistCurrency(
        address currency,
        bool status
    ) external onlyOwner {
        isCurrencyWhitelisted[currency] = status;
    }

    function distribute(
        address currency,
        address[] memory beneficiaries,
        uint256[] memory rewards
    ) external {
        require(beneficiaries.length == rewards.length, "array length not equal");
        require(isCurrencyWhitelisted[currency], "currency not whitelisted");

        for(uint256 i = 0; i < beneficiaries.length; ++i) {
            IERC20(currency).safeTransferFrom(
                msg.sender,
                beneficiaries[i],
                rewards[i]
            );
        }

        emit Distributed(
            msg.sender,
            currency,
            beneficiaries,
            rewards
        );
    }
}
