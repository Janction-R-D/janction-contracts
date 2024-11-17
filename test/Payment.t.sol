// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {Payment} from "../src/Payment.sol";
import {TestCurrency} from "./mocks/TestCurrency.sol";

contract PaymentTest is Test {
    Payment public payment;
    TestCurrency public token;
    address public owner = address(0x123);
    address public tenant = address(0x456);
    bytes32 public nodeId = keccak256("testNode");

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock token and mint some tokens for testing
        token = new TestCurrency();
        token.mint(tenant, 1e18);

        // Deploy the payment contract
        payment = new Payment(owner);

        // Whitelist the mock token
        payment.whitelistCurrency(address(token), true);

        vm.stopPrank();
    }

    function testList() public {
        uint256 baseAmount = 100;

        vm.startPrank(owner);
        payment.list(nodeId, address(token), baseAmount);
        Payment.Listing memory listing = payment.getListing(owner, nodeId);

        assertEq(
            uint256(listing.status),
            uint256(Payment.ListingStatus.Listing)
        );
        assertEq(listing.owner, owner);
        assertEq(listing.currency, address(token));
        assertEq(listing.baseAmount, baseAmount);
        vm.stopPrank();
    }

    function testRent() public {
        uint256 baseAmount = 100;

        // Owner lists the node
        vm.startPrank(owner);
        payment.list(nodeId, address(token), baseAmount);
        vm.stopPrank();

        // Tenant rents the node
        uint256 totalAmount = 100 * 6; // 6 days for weekly duration
        vm.startPrank(tenant);
        token.approve(address(payment), totalAmount);
        payment.rent(owner, nodeId, Payment.Duration.Week);

        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(uint256(rental.status), uint256(Payment.RentalStatus.Renting));
        assertEq(rental.tenant, tenant);
        assertEq(rental.currency, address(token));
        assertEq(rental.totalAmount, totalAmount);
        assertEq(rental.totalDays, 7);
        assertEq(rental.dailyAmount, totalAmount / 7);
        vm.stopPrank();
    }

    function testReleaseDailyPayment() public {
        uint256 baseAmount = 100;

        // Owner lists the node
        vm.startPrank(owner);
        payment.list(nodeId, address(token), baseAmount);
        vm.stopPrank();

        // Tenant rents the node
        uint256 totalAmount = 100 * 6; // 6 days for weekly duration
        vm.startPrank(tenant);
        token.approve(address(payment), totalAmount);
        payment.rent(owner, nodeId, Payment.Duration.Week);
        vm.stopPrank();

        // Owner releases the daily payment
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(owner);
        payment.releaseDailyPayment(owner, nodeId);

        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(rental.paidDays, 1);
        assertEq(token.balanceOf(owner), totalAmount / 7);
        vm.stopPrank();
    }

    function testListNode_RevertWhenCurrencyNotWhitelisted() public {
        address unwhitelistedCurrency = address(0x789);
        uint256 baseAmount = 100;

        vm.startPrank(owner);
        vm.expectRevert("currency not whitelisted");
        payment.list(nodeId, unwhitelistedCurrency, baseAmount);
        vm.stopPrank();
    }

    function testListNode_RevertWhenNodeAlreadyListed() public {
        uint256 baseAmount = 100;

        vm.startPrank(owner);
        payment.list(nodeId, address(token), baseAmount);

        vm.expectRevert("node has been listed");
        payment.list(nodeId, address(token), baseAmount);
        vm.stopPrank();
    }

    function testRentNode_RevertWhenNodeNotListed() public {
        vm.startPrank(tenant);
        vm.expectRevert("node not listing");
        payment.rent(owner, nodeId, Payment.Duration.Week);
        vm.stopPrank();
    }

    function testRentNode_RevertWhenNodeAlreadyRented() public {
        uint256 baseAmount = 100;

        // Owner lists the node
        vm.startPrank(owner);
        payment.list(nodeId, address(token), baseAmount);
        vm.stopPrank();

        // Tenant rents the node
        uint256 totalAmount = 100 * 6; // 6 days for weekly duration
        vm.startPrank(tenant);
        token.approve(address(payment), totalAmount);
        payment.rent(owner, nodeId, Payment.Duration.Week);
        vm.stopPrank();

        // Another tenant tries to rent the same node
        vm.startPrank(address(0x789));
        token.mint(address(0x789), totalAmount);
        token.approve(address(payment), totalAmount);

        vm.expectRevert("node has tenants");
        payment.rent(owner, nodeId, Payment.Duration.Week);
        vm.stopPrank();
    }

    function testReleaseDailyPayment_RevertWhenNoPaymentRental() public {
        vm.startPrank(owner);
        vm.expectRevert("no payment rental found for this payee");
        payment.releaseDailyPayment(owner, nodeId);
        vm.stopPrank();
    }

    function testReleaseDailyPayment_RevertWhenAllPaymentsMade() public {
        uint256 baseAmount = 100;

        // Owner lists the node
        vm.startPrank(owner);
        payment.list(nodeId, address(token), baseAmount);
        vm.stopPrank();

        // Tenant rents the node
    }
}
