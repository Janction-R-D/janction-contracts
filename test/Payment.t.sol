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
    address admin;
    uint256 adminPK;
    address payer;
    uint256 payerPK;
    address recipient;

    function setUp() public {
        (owner, ownerPK) = makeAddrAndKey("owner");
        (payer, payerPK) = makeAddrAndKey("payer");
        (admin, adminPK) = makeAddrAndKey("admin");
        recipient = makeAddr("recipient");

        PaymentImpl paymentImpl = new PaymentImpl();

        ERC1967Proxy paymentProxy = new ERC1967Proxy(
            address(paymentImpl),
            abi.encodeWithSelector(
                PaymentImpl.initialize.selector,
                owner,
                admin,
                2
            )
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
        uint256 totalHours = 240; // 10 days worth of hours

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
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
        assertEq(plan.hourlyAmount, totalAmount / totalHours);
        assertEq(plan.totalHours, totalHours);
        assertEq(plan.paidHours, 0);
        assertEq(plan.startTime, block.timestamp);

        vm.stopPrank();
    }

    function testStopPaymentPlan() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Generate EIP-712 signatures from payer and owner
        uint256 deadline = block.timestamp + 3600;
        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = adminPK;
        privateKeys[1] = payerPK;
        address[] memory signers = new address[](2);
        signers[0] = admin;
        signers[1] = payer;

        PaymentImpl.EIP712Signature[] memory signatures = _generateSignatures(
            paymentId,
            deadline,
            privateKeys,
            signers
        );

        payment.stopPaymentPlan(paymentId, signatures);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertTrue(plan.stopped);

        vm.stopPrank();
    }

    function testStopPaymentPlanWhenPassedHours() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Advance 24 hours
        vm.warp(block.timestamp + 24 hours);

        // Generate EIP-712 signatures with updated deadline
        uint256 deadline = block.timestamp + 3600; // Use current block.timestamp

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = adminPK;
        privateKeys[1] = payerPK;
        address[] memory signers = new address[](2);
        signers[0] = admin;
        signers[1] = payer;

        PaymentImpl.EIP712Signature[] memory signatures = _generateSignatures(
            paymentId,
            deadline,
            privateKeys,
            signers
        );

        payment.stopPaymentPlan(paymentId, signatures);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertTrue(plan.stopped);
        assertEq(plan.paidHours, 24);
        assertEq(
            mockToken.balanceOf(recipient),
            (totalAmount / totalHours) * 24
        );

        vm.stopPrank();
    }

    function testCannotStopPaymentPlanWhenAlreadyStopped() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Generate EIP-712 signatures
        uint256 deadline = block.timestamp + 3600;
        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = adminPK;
        privateKeys[1] = payerPK;
        address[] memory signers = new address[](2);
        signers[0] = admin;
        signers[1] = payer;

        PaymentImpl.EIP712Signature[] memory signatures = _generateSignatures(
            paymentId,
            deadline,
            privateKeys,
            signers
        );

        // Stop the payment plan
        payment.stopPaymentPlan(paymentId, signatures);

        // Try to stop it again
        vm.expectRevert("payment has already stopped");
        payment.stopPaymentPlan(paymentId, signatures);

        vm.stopPrank();
    }

    function testCannotStopPaymentPlanWithInsufficientSignatures() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Generate EIP-712 signature from payer only
        uint256 deadline = block.timestamp + 3600;
        uint256[] memory privateKeys = new uint256[](1);
        privateKeys[0] = payerPK;
        address[] memory signers = new address[](1);
        signers[0] = payer;

        PaymentImpl.EIP712Signature[] memory signatures = _generateSignatures(
            paymentId,
            deadline,
            privateKeys,
            signers
        );

        vm.expectRevert("insufficient signatures");
        payment.stopPaymentPlan(paymentId, signatures);

        vm.stopPrank();
    }

    function testCannotStopPaymentPlanWithInsufficientValidSignatures() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Generate EIP-712 signatures from payer and owner
        uint256 deadline = block.timestamp + 3600;
        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = adminPK;
        privateKeys[1] = payerPK;
        address[] memory signers = new address[](2);
        signers[0] = admin;
        signers[1] = address(0xDEAD); // Invalid signer to trigger "recovered address not equal to signer"

        PaymentImpl.EIP712Signature[] memory signatures = _generateSignatures(
            paymentId,
            deadline,
            privateKeys,
            signers
        );

        vm.expectRevert("recovered address not equal to signer");
        payment.stopPaymentPlan(paymentId, signatures);

        vm.stopPrank();
    }

    function testReleaseHourlyPayment() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Advance slightly more than 1 hour to ensure the time check passes
        uint256 nextTime = 3601;
        vm.warp(nextTime);

        payment.releaseHourlyPayment(paymentId);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidHours, 1);
        assertEq(mockToken.balanceOf(recipient), totalAmount / totalHours);

        // Advance another hour and release again
        nextTime = 7202;
        vm.warp(nextTime);

        payment.releaseHourlyPayment(paymentId);

        plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidHours, 2);
        assertEq(
            mockToken.balanceOf(recipient),
            2 * (totalAmount / totalHours)
        );

        vm.stopPrank();
    }

    function testReleaseFinalPayment() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // Warp to the last payment hour
        vm.warp(block.timestamp + totalHours * 1 hours);

        payment.releaseHourlyPayment(paymentId);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidHours, totalHours);
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
            240
        );
        vm.stopPrank();
    }

    function testCannotReleaseBeforeTime() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 240;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        vm.expectRevert("not yet time for the next payment");
        payment.releaseHourlyPayment(paymentId);

        vm.stopPrank();
    }

    // Helper function to generate EIP-712 signatures
    function _generateSignatures(
        bytes32 paymentId,
        uint256 deadline,
        uint256[] memory privateKeys,
        address[] memory signers
    ) internal view returns (PaymentImpl.EIP712Signature[] memory) {
        bytes32 stopPaymentPlanTypeHash = payment.STOP_PAYMENT_PLAN_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(stopPaymentPlanTypeHash, paymentId, deadline)
        );
        bytes32 domainSeparator = payment.getDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        PaymentImpl.EIP712Signature[]
            memory signatures = new PaymentImpl.EIP712Signature[](
                privateKeys.length
            );
        for (uint256 i = 0; i < privateKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], digest);
            signatures[i] = PaymentImpl.EIP712Signature({
                signer: signers[i],
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });
        }
        return signatures;
    }
}
