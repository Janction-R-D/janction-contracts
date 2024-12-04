// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {Payment} from "../src/Payment.sol";
import {TestCurrency} from "./mocks/TestCurrency.sol";

contract PaymentTest is Test {
    Payment payment;
    TestCurrency usdt;
    TestCurrency usdc;
    TestCurrency jct;

    address owner = address(0x1);
    address tenant = address(0x2);

    bytes32 nodeId = keccak256("testNode");

    function setUp() public {
        usdt = new TestCurrency("USDT", "USDT", 6);
        usdc = new TestCurrency("USDC", "USDC", 6);
        jct = new TestCurrency("ve JCT", "veJCT", 18);

        payment = new Payment(owner);

        vm.prank(owner);
        payment.whitelistCurrency(address(usdt), true);
        vm.prank(owner);
        payment.whitelistCurrency(address(usdc), true);
        vm.prank(owner);
        payment.whitelistCurrency(address(jct), true);
    }

    function testListAndDelist() public {
        // Simulate the owner listing a node with a base amount of 1000
        vm.prank(owner);
        payment.list(nodeId, 1000);

        // Verify the listing details
        Payment.Listing memory listing = payment.getListing(owner, nodeId);
        assertEq(
            uint256(listing.status),
            uint256(Payment.ListingStatus.Listing)
        );
        assertEq(listing.owner, owner);
        assertEq(listing.baseAmount, 1000);

        // Simulate the owner delisting the node
        vm.prank(owner);
        payment.delist(nodeId);

        // Verify the node is delisted
        listing = payment.getListing(owner, nodeId);
        assertEq(
            uint256(listing.status),
            uint256(Payment.ListingStatus.NotList)
        );
    }

    function testRentAndReleasePayment() public {
        // Simulate the owner listing a node
        vm.prank(owner);
        payment.list(nodeId, 1000);

        uint256 totalAmount = 3000; // Total payment amount
        uint256 totalDays = 3; // Total rental days
        uint256 dailyAmount = totalAmount / totalDays;

        // Simulate the tenant renting the node
        usdt.mint(tenant, totalAmount); // Mint sufficient USDT for the tenant
        vm.startPrank(tenant);
        usdt.approve(address(payment), totalAmount); // Approve the payment
        payment.rent(owner, nodeId, address(usdt), totalAmount, totalDays);
        vm.stopPrank();

        // Verify the rental details
        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(uint256(rental.status), uint256(Payment.RentalStatus.Renting));
        assertEq(rental.tenant, tenant);
        assertEq(rental.totalAmount, totalAmount);
        assertEq(rental.dailyAmount, dailyAmount);

        // Fast forward 1 day and release the first daily payment
        vm.warp(block.timestamp + 1 days);
        vm.prank(tenant);
        payment.releaseDailyPayment(owner, nodeId);

        rental = payment.getRental(owner, nodeId);
        assertEq(rental.paidDays, 1); // Verify 1 day of payment has been made
        assertEq(usdt.balanceOf(owner), dailyAmount); // Verify owner received payment for 1 day

        // Fast forward another day and release the second daily payment
        vm.warp(block.timestamp + 1 days);
        vm.prank(tenant);
        payment.releaseDailyPayment(owner, nodeId);

        rental = payment.getRental(owner, nodeId);
        assertEq(rental.paidDays, 2); // Verify 2 days of payment have been made
        assertEq(usdt.balanceOf(owner), dailyAmount * 2); // Verify owner received payment for 2 days

        // Fast forward to the third day and release the final payment
        vm.warp(block.timestamp + 1 days);
        vm.prank(tenant);
        payment.releaseDailyPayment(owner, nodeId);

        rental = payment.getRental(owner, nodeId);
        assertEq(uint256(rental.status), uint256(Payment.RentalStatus.NotRent)); // Verify rental is complete
        assertEq(rental.paidDays, totalDays); // Verify all days have been paid
        assertEq(usdt.balanceOf(owner), totalAmount); // Verify owner received the total payment
    }
}
