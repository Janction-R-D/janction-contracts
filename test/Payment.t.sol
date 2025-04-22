// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";
import {CurrencyMock} from "./mocks/CurrencyMock.sol";

contract PaymentTest is Test {
    error OwnableUnauthorizedAccount(address account);

    PaymentImpl payment;
    CurrencyMock mockToken;
    address owner;
    uint256 ownerPK;
    address payer;
    uint256 payerPK;
    address recipient;
    uint256 recipientPK;
    address admin;
    uint256 adminPK;

    function setUp() public {
        (owner, ownerPK) = makeAddrAndKey("owner");
        (payer, payerPK) = makeAddrAndKey("payer");
        (recipient, recipientPK) = makeAddrAndKey("recipient");
        (admin, adminPK) = makeAddrAndKey("admin");

        PaymentImpl paymentImpl = new PaymentImpl();

        ERC1967Proxy paymentProxy = new ERC1967Proxy(
            address(paymentImpl),
            abi.encodeWithSelector(
                PaymentImpl.initialize.selector,
                owner,
                admin,
                2 // 需要2个签名
            )
        );

        payment = PaymentImpl(address(paymentProxy));
        mockToken = new CurrencyMock("Currency Mock", "CM", 18);
        mockToken.mint(payer, 1_000 ether);

        vm.prank(owner);
        payment.whitelistCurrency(address(mockToken), true);
    }

    // ========== 基础功能测试 ==========

    function testCreatePaymentPlan() public {
        uint256 totalAmount = 100 ether;
        uint256 totalPeriods = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
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
        assertEq(plan.periodAmount, totalAmount / totalPeriods);
        assertEq(plan.totalPeriods, totalPeriods);
        assertEq(plan.paidPeriods, 0);
        assertEq(plan.startTime, block.timestamp);
        assertEq(
            uint(plan.granularity),
            uint(PaymentImpl.TimeGranularity.DAYS)
        );

        vm.stopPrank();
    }

    function testStopPaymentPlanWithEIP712Signatures() public {
        uint256 totalAmount = 100 ether;
        uint256 totalPeriods = 10;
        uint256 deadline = block.timestamp + 1 days;

        // 创建支付计划
        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 准备EIP712签名
        bytes32 typeHash = payment.STOP_PAYMENT_PLAN_TYPEHASH();
        bytes32 digest = keccak256(abi.encode(typeHash, paymentId, deadline));
        bytes32 domainSeparator = payment.getDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, digest)
        );

        // 生成签名
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(adminPK, structHash); // admin
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, structHash); // payer

        PaymentImpl.EIP712Signature[]
            memory signatures = new PaymentImpl.EIP712Signature[](2);
        signatures[0] = PaymentImpl.EIP712Signature({
            signer: admin,
            v: v1,
            r: r1,
            s: s1,
            deadline: deadline
        });
        signatures[1] = PaymentImpl.EIP712Signature({
            signer: payer,
            v: v2,
            r: r2,
            s: s2,
            deadline: deadline
        });

        // 执行停止
        payment.stopPaymentPlan(paymentId, signatures);

        // 验证状态
        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertTrue(plan.stopped);
    }

    function testReleaseHourlyPayment() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 24; // 24小时支付计划

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours,
            PaymentImpl.TimeGranularity.HOURS // 小时粒度
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 前进1小时
        vm.warp(block.timestamp + 1 hours);

        payment.releasePeriodPayment(paymentId);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidPeriods, 1);
        assertEq(mockToken.balanceOf(recipient), totalAmount / totalHours);

        // 前进12小时
        vm.warp(block.timestamp + 12 hours);

        payment.releasePeriodPayment(paymentId);

        plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidPeriods, 13); // 1 + 12
        assertEq(
            mockToken.balanceOf(recipient),
            13 * (totalAmount / totalHours)
        );

        vm.stopPrank();
    }

    function testFinalHourlyPaymentAccuracy() public {
        uint256 totalAmount = 100.5 ether; // 测试非整除金额
        uint256 totalHours = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);

        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours,
            PaymentImpl.TimeGranularity.HOURS
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 前进全部时间
        vm.warp(block.timestamp + totalHours * 1 hours);

        payment.releasePeriodPayment(paymentId);

        // 验证最终金额精确性
        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidPeriods, totalHours);
        assertEq(mockToken.balanceOf(recipient), totalAmount); // 应收到全部金额
        assertEq(mockToken.balanceOf(address(payment)), 0); // 合约余额应为0
    }

    // ========== 签名验证边界测试 ==========

    function testCannotStopWithExpiredSignature() public {
        uint256 totalAmount = 100 ether;
        uint256 totalPeriods = 10;
        uint256 deadline = block.timestamp + 1 hours; // 短期有效期

        // 创建支付计划
        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 准备签名
        bytes32 typeHash = payment.STOP_PAYMENT_PLAN_TYPEHASH();
        bytes32 digest = keccak256(abi.encode(typeHash, paymentId, deadline));
        bytes32 domainSeparator = payment.getDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, digest)
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(adminPK, structHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, structHash);

        PaymentImpl.EIP712Signature[]
            memory signatures = new PaymentImpl.EIP712Signature[](2);
        signatures[0] = PaymentImpl.EIP712Signature({
            signer: admin,
            v: v1,
            r: r1,
            s: s1,
            deadline: deadline
        });
        signatures[1] = PaymentImpl.EIP712Signature({
            signer: payer,
            v: v2,
            r: r2,
            s: s2,
            deadline: deadline
        });

        // 时间超过deadline
        vm.warp(deadline + 1);

        // 应失败
        vm.expectRevert("signature expired");
        payment.stopPaymentPlan(paymentId, signatures);
    }

    function testCannotStopWithInvalidSigner() public {
        uint256 totalAmount = 100 ether;
        uint256 totalPeriods = 10;
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 使用无效签名者(随机地址)
        (address invalidSigner, uint256 invalidPK) = makeAddrAndKey("invalid");

        bytes32 typeHash = payment.STOP_PAYMENT_PLAN_TYPEHASH();
        bytes32 digest = keccak256(abi.encode(typeHash, paymentId, deadline));
        bytes32 domainSeparator = payment.getDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, digest)
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(invalidPK, structHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, structHash);

        PaymentImpl.EIP712Signature[]
            memory signatures = new PaymentImpl.EIP712Signature[](2);
        signatures[0] = PaymentImpl.EIP712Signature({
            signer: invalidSigner,
            v: v1,
            r: r1,
            s: s1,
            deadline: deadline
        });
        signatures[1] = PaymentImpl.EIP712Signature({
            signer: payer,
            v: v2,
            r: r2,
            s: s2,
            deadline: deadline
        });

        vm.expectRevert("insufficient valid signatures");
        payment.stopPaymentPlan(paymentId, signatures);
    }

    function testCannotStopWithDuplicateSignatures() public {
        uint256 totalAmount = 100 ether;
        uint256 totalPeriods = 10;
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        bytes32 typeHash = payment.STOP_PAYMENT_PLAN_TYPEHASH();
        bytes32 digest = keccak256(abi.encode(typeHash, paymentId, deadline));
        bytes32 domainSeparator = payment.getDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, digest)
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(payerPK, structHash);

        // 使用相同的签名两次
        PaymentImpl.EIP712Signature[]
            memory signatures = new PaymentImpl.EIP712Signature[](2);
        signatures[0] = PaymentImpl.EIP712Signature({
            signer: payer,
            v: v1,
            r: r1,
            s: s1,
            deadline: deadline
        });
        signatures[1] = signatures[0]; // 重复签名

        vm.expectRevert("insufficient valid signatures");
        payment.stopPaymentPlan(paymentId, signatures);
    }

    // ========== 时间边界测试 ==========

    function testReleasePartialPeriod() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 24;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours,
            PaymentImpl.TimeGranularity.HOURS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 前进30分钟(不足1小时)
        vm.warp(block.timestamp + 30 minutes);

        // 不应释放任何支付
        vm.expectRevert("not yet time for the next payment");
        payment.releasePeriodPayment(paymentId);
    }

    function testReleaseAtExactPeriodBoundary() public {
        uint256 totalAmount = 100 ether;
        uint256 totalHours = 24;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalHours,
            PaymentImpl.TimeGranularity.HOURS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 精确前进1小时
        vm.warp(block.timestamp + 1 hours);

        payment.releasePeriodPayment(paymentId);

        PaymentImpl.PaymentPlan memory plan = payment.getPaymentPlan(paymentId);
        assertEq(plan.paidPeriods, 1);
        assertEq(mockToken.balanceOf(recipient), totalAmount / totalHours);
    }

    // ========== 金额边界测试 ==========

    function testSmallAmountDivision() public {
        uint256 totalAmount = 9; // 极小金额
        uint256 totalPeriods = 3;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 前进1天
        vm.warp(block.timestamp + 1 days);

        payment.releasePeriodPayment(paymentId);

        // 验证9/3=3个token被释放
        assertEq(mockToken.balanceOf(recipient), 3);
    }

    function testAmountNotDivisibleByPeriods() public {
        uint256 totalAmount = 100.001 ether; // 不能被整除的金额
        uint256 totalPeriods = 3;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 前进全部时间
        vm.warp(block.timestamp + totalPeriods * 1 days);

        payment.releasePeriodPayment(paymentId);

        // 验证最终金额精确性
        assertEq(mockToken.balanceOf(recipient), totalAmount);
        assertEq(mockToken.balanceOf(address(payment)), 0);
    }

    // ========== 权限边界测试 ==========

    function testNonOwnerCannotWhitelist() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                attacker
            )
        );
        payment.whitelistCurrency(address(mockToken), false);
    }

    function testNonAdminCannotSetThreshold() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                attacker
            )
        );
        payment.setSignatureThreshold(1);
    }

    // ========== 状态边界测试 ==========

    function testCannotReleaseAfterStopped() public {
        uint256 totalAmount = 100 ether;
        uint256 totalPeriods = 10;

        vm.startPrank(payer);
        mockToken.approve(address(payment), totalAmount);
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            totalAmount,
            totalPeriods,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, uint256(0))
        );

        // 停止支付计划
        uint256 deadline = block.timestamp + 1 days;
        bytes32 typeHash = payment.STOP_PAYMENT_PLAN_TYPEHASH();
        bytes32 digest = keccak256(abi.encode(typeHash, paymentId, deadline));
        bytes32 domainSeparator = payment.getDomainSeparator();
        bytes32 structHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, digest)
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(adminPK, structHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(payerPK, structHash);

        PaymentImpl.EIP712Signature[]
            memory signatures = new PaymentImpl.EIP712Signature[](2);
        signatures[0] = PaymentImpl.EIP712Signature({
            signer: admin,
            v: v1,
            r: r1,
            s: s1,
            deadline: deadline
        });
        signatures[1] = PaymentImpl.EIP712Signature({
            signer: payer,
            v: v2,
            r: r2,
            s: s2,
            deadline: deadline
        });

        payment.stopPaymentPlan(paymentId, signatures);

        // 尝试释放
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("payment has already stopped");
        payment.releasePeriodPayment(paymentId);
    }

    // ========== 其他边界测试 ==========

    function testCannotCreatePlanWithZeroAmount() public {
        vm.startPrank(payer);
        mockToken.approve(address(payment), 0);

        vm.expectRevert("period release amount must be greater than zero");
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            0, // 零金额
            10,
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();
    }

    function testCannotCreatePlanWithZeroPeriods() public {
        vm.startPrank(payer);
        mockToken.approve(address(payment), 100 ether);

        vm.expectRevert("total periods must be greater than zero");
        payment.createPaymentPlan(
            payer,
            recipient,
            address(mockToken),
            100 ether,
            0, // 零周期
            PaymentImpl.TimeGranularity.DAYS
        );
        vm.stopPrank();
    }
}
