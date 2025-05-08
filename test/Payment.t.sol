// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";
import {CurrencyMock} from "./mocks/CurrencyMock.sol";

contract PaymentTest is Test {
    PaymentImpl payment;
    CurrencyMock mockToken;
    address owner;
    uint256 ownerPK;
    address payer;
    uint256 payerPK;
    address recipient;

    function setUp() public {
        (owner, ownerPK) = makeAddrAndKey("owner");
        (payer, payerPK) = makeAddrAndKey("payer");
        recipient = makeAddr("recipient");

        PaymentImpl paymentImpl = new PaymentImpl();

        ERC1967Proxy paymentProxy = new ERC1967Proxy(
            address(paymentImpl),
            abi.encodeWithSelector(PaymentImpl.initialize.selector, owner, 2)
        );

        payment = PaymentImpl(address(paymentProxy));

        mockToken = new CurrencyMock("Currency Mock", "CM", 18);
        mockToken.mint(payer, 1_000 ether);

        vm.prank(owner);
        payment.whitelistCurrency(address(mockToken), true);
    }

    function testSetSignatureThreshold() public {
        vm.prank(owner);
        payment.setSignatureThreshold(1);
        assertEq(payment.signatureThreshold(), 1);

        vm.prank(owner);
        payment.setSignatureThreshold(2);
        assertEq(payment.signatureThreshold(), 2);
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

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );
        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);

        assertEq(plan.stopped, false);
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

    function testStopPaymentPlan() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Generate signatures from payer and owner
        bytes32 messageHash = keccak256(abi.encodePacked(paymentId, "STOP"));
        bytes32 prefixedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerPK, prefixedMessageHash); // owner
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, prefixedMessageHash); // payer

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1); // owner
        signatures[1] = abi.encodePacked(r2, s2, v2); // payer

        payment.stopPaymentPlan(paymentId, signatures);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertTrue(plan.stopped);

        vm.stopPrank();
    }

    function testStopPaymentPlanWhenPassedDays() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Advance 1 day
        vm.warp(block.timestamp + 1 days);

        // Generate signatures from payer and owner
        bytes32 messageHash = keccak256(abi.encodePacked(paymentId, "STOP"));
        bytes32 prefixedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerPK, prefixedMessageHash); // owner
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, prefixedMessageHash); // payer

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1); // owner
        signatures[1] = abi.encodePacked(r2, s2, v2); // payer

        payment.stopPaymentPlan(paymentId, signatures);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertTrue(plan.stopped);
        assertEq(plan.paidDays, 1);
        assertEq(mockToken.balanceOf(recipient), totalAmount / totalDays);

        vm.stopPrank();
    }

    function testCannotStopPaymentPlanWhenAlreadyStopped() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        bytes32 messageHash = keccak256(abi.encodePacked(paymentId, "STOP"));
        bytes32 prefixedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerPK, prefixedMessageHash); // owner
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, prefixedMessageHash); // payer

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1); // owner
        signatures[1] = abi.encodePacked(r2, s2, v2); // payer

        payment.stopPaymentPlan(paymentId, signatures);

        vm.expectRevert("payment has already stopped");
        payment.stopPaymentPlan(paymentId, signatures);
    }

    function testCannotStopPaymentPlanWithInsufficientSignatures() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        bytes32 messageHash = keccak256(abi.encodePacked(paymentId, "STOP"));
        bytes32 prefixedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, prefixedMessageHash); // payer

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(r2, s2, v2); // payer

        vm.expectRevert("insufficient signatures");
        payment.stopPaymentPlan(paymentId, signatures);
    }

    function testCannotStopPaymentPlanWithInsufficientValidSignatures() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        bytes32 messageHash = keccak256(abi.encodePacked(paymentId, "STOP"));
        bytes32 prefixedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerPK, prefixedMessageHash); // owner
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, prefixedMessageHash); // payer

        uint8 wrongV2 = v2 + 1;

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1); // owner
        signatures[1] = abi.encodePacked(r2, s2, wrongV2); // payer

        vm.expectRevert("insufficient valid signatures");
        payment.stopPaymentPlan(paymentId, signatures);
    }

    function testReleaseDailyPayment() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Advance 1 day
        vm.warp(block.timestamp + 1 days);

        payment.releaseDailyPayment(paymentId);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
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

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Warp to the last payment day
        vm.warp(block.timestamp + totalDays * 1 days);

        payment.releaseDailyPayment(paymentId);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidDays, totalDays);
        assertEq(mockToken.balanceOf(recipient), totalAmount);

        vm.stopPrank();
    }

    function testCannotCreatePlanWithNonWhitelistedCurrency() public {
        address unwhitelistedToken = address(0xDEAD);

        vm.startPrank(payer);
        vm.expectRevert("currency not whitelisted");
        payment.createPaymentPlan(
            payer,
            recipient,
            unwhitelistedToken,
            100 ether,
            10
        );
        vm.stopPrank();
    }

    function testCannotReleaseBeforeTime() public {
        uint256 totalAmount = 100 ether;
        uint256 totalDays = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalDays
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        vm.expectRevert("not yet time for the next payment");
        payment.releaseDailyPayment(paymentId);

        vm.stopPrank();
    }
}
