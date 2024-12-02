// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IPriceOracle {
    /// @notice Return price decimals
    /// @return decimals
    function decimals() external view returns (uint8);

    /// @notice Return the current token price in USD
    /// @return tokenPrice
    function getPrice() external view returns (uint256 tokenPrice);
} 