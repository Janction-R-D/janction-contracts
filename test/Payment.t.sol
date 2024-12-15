// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/Payment.sol";
import "./mocks/CurrencyMock.sol";

contract PaymentTest is Test {
    Payment public payment;
    CurrencyMock public mockToken;
    address public owner = address(1);
    address public payer = address(2);
    address public recipient = address(3);

    function setUp() public {
        vm.prank(owner);
        payment = new Payment(owner);

        mockToken = new CurrencyMock("Currency Mock", "CM", 18);
        mockToken.mint(payer, 1_000 ether);

        vm.startPrank(owner);
        payment.whitelistCurrency(address(mockToken), true);
        vm.stopPrank();
    }

    function testWhitelistCurrency() public {
        vm.prank(owner);
        payment.whitelistCurrency(address(mockToken), false);
        assertFalse(payment.isCurrencyWhitelisted(address(mockToken)));

        vm.prank(owner);
        payment.whitelistCurrency(address(mockToken), true);
        assertTrue(payment.isCurrencyWhitelisted(address(mockToken)));
    }

    function testCreatePaymentPlan() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(payer, recipient, address(mockToken), totalAmount, totalDays);

        bytes32 paymentId = keccak256(abi.encodePacked(payer, recipient, uint256(0)));
        Payment.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);

        assertEq(plan.payer, payer);
        assertEq(plan.recipient, recipient);
        assertEq(plan.currency, address(mockToken));
        assertEq(plan.totalAmount, totalAmount);
        assertEq(plan.dailyAmount, totalAmount / totalDays);
        assertEq(plan.totalDays, totalDays);
        assertEq(plan.paidDays, 0);
        assertEq(plan.startTime, block.timestamp);

        vm.stopPrank();
    }

    function testReleaseDailyPayment() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(payer, recipient, address(mockToken), totalAmount, totalDays);

        bytes32 paymentId = keccak256(abi.encodePacked(payer, recipient, uint256(0)));

        // Advance 1 day
        vm.warp(block.timestamp + 1 days);

        payment.releaseDailyPayment(paymentId);

        Payment.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidDays, 1);
        assertEq(mockToken.balanceOf(recipient), totalAmount / totalDays);

        // Advance another day and release again
        vm.warp(block.timestamp + 1 days);

        payment.releaseDailyPayment(paymentId);

        plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidDays, 2);
        assertEq(mockToken.balanceOf(recipient), 2 * (totalAmount / totalDays));

        vm.stopPrank();
    }

    function testReleaseFinalPayment() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(payer, recipient, address(mockToken), totalAmount, totalDays);

        bytes32 paymentId = keccak256(abi.encodePacked(payer, recipient, uint256(0)));

        // Warp to the last payment day
        vm.warp(block.timestamp + totalDays * 1 days);

        payment.releaseDailyPayment(paymentId);

        Payment.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidDays, totalDays);
        assertEq(mockToken.balanceOf(recipient), totalAmount);

        vm.stopPrank();
    }

    function testCannotCreatePlanWithNonWhitelistedCurrency() public {
        address unwhitelistedToken = address(0xDEAD);

        vm.startPrank(payer);
        vm.expectRevert("currency not whitelisted");
        payment.createPaymentPlan(payer, recipient, unwhitelistedToken, 100 ether, 10);
        vm.stopPrank();
    }

    function testCannotReleaseBeforeTime() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(payer, recipient, address(mockToken), totalAmount, totalDays);

        bytes32 paymentId = keccak256(abi.encodePacked(payer, recipient, uint256(0)));

        vm.expectRevert("not yet time for the next payment");
        payment.releaseDailyPayment(paymentId);

        vm.stopPrank();
    }
}
