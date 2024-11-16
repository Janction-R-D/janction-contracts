// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCurrency is ERC20 {
    constructor() ERC20("Test Currency", "TC") {}

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}