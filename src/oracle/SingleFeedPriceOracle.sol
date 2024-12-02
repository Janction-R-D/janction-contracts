// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "./IPriceOracle.sol";

/// A simple price oracle that receives price update from owner only.
contract SingleFeedPriceOracle is IPriceOracle, Ownable {
    uint256 private _price;
    uint256 public lastUpdatedAt;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function getPrice() external view override returns (uint256) {
        return _price;
    }

    function setPrice(uint256 requestedPrice) external onlyOwner {
        require(requestedPrice > 0, "PriceOracle: invalid price");

        _price = requestedPrice;
        lastUpdatedAt = block.timestamp;
    }
}
