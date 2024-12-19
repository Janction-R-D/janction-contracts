// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {Distribution} from "../src/Distribution.sol";
import {CurrencyMock} from "./mocks/CurrencyMock.sol";

contract DistributionTest is Test {
    Distribution public distribution;
    CurrencyMock public currencyMock;
    address public owner;
    address public treasury;

    address public beneficiary1 = address(0x1);
    address public beneficiary2 = address(0x2);

    function setUp() public {
        owner = address(this);
        treasury = address(0x100);

        // Deploy mock ERC20 token
        currencyMock = new CurrencyMock("MockToken", "MTK", 18);

        // Deploy Distribution contract
        distribution = new Distribution(owner, treasury);

        // Whitelist the mock currency
        distribution.whitelistCurrency(address(currencyMock), true);

        // Mint tokens to the owner
        currencyMock.mint(owner, 1_000_000 ether);

        // Approve Distribution contract to spend owner's tokens
        currencyMock.approve(address(distribution), type(uint256).max);
    }

    function testWhitelistCurrency() public {
        address newCurrency = address(0x200);
        assertEq(distribution.isCurrencyWhitelisted(newCurrency), false);

        distribution.whitelistCurrency(newCurrency, true);
        assertEq(distribution.isCurrencyWhitelisted(newCurrency), true);

        distribution.whitelistCurrency(newCurrency, false);
        assertEq(distribution.isCurrencyWhitelisted(newCurrency), false);
    }

    function testSetTreasury() public {
        address newTreasury = address(0x300);
        distribution.setTreasury(newTreasury);
        assertEq(distribution.treasury(), newTreasury);
    }

    function testDistribute() public {
        uint256 totalAmount = 350 ether;

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = 100 ether;
        rewards[1] = 200 ether;

        assertEq(currencyMock.balanceOf(beneficiary1), 0);
        assertEq(currencyMock.balanceOf(beneficiary2), 0);
        assertEq(currencyMock.balanceOf(treasury), 0);

        uint256 ownerBalanceBefore = currencyMock.balanceOf(owner);

        distribution.distribute(
            address(currencyMock),
            totalAmount,
            beneficiaries,
            rewards
        );

        uint256 ownerBalanceAfter = currencyMock.balanceOf(owner);

        assertEq(currencyMock.balanceOf(beneficiary1), 100 ether);
        assertEq(currencyMock.balanceOf(beneficiary2), 200 ether);
        assertEq(currencyMock.balanceOf(treasury), 50 ether);

        assertEq(ownerBalanceBefore - ownerBalanceAfter, totalAmount);
    }

    function testDistributeRevertsIfCurrencyNotWhitelisted() public {
        address unwhitelistedCurrency = address(0x400);

        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = beneficiary1;

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = 100 ether;

        vm.expectRevert("currency not whitelisted");
        distribution.distribute(
            unwhitelistedCurrency,
            100 ether,
            beneficiaries,
            rewards
        );
    }

    function testDistributeRevertsIfArrayLengthsMismatch() public {
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = 100 ether;

        vm.expectRevert("array length not equal");
        distribution.distribute(
            address(currencyMock),
            200 ether,
            beneficiaries,
            rewards
        );
    }
}
