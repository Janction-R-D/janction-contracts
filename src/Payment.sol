// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Payment is Ownable {
    struct PaymentPlan {
        address payer; // payer address
        address recipient; // recipient address
        address currency; // payment currency
        uint256 totalAmount; // Total one-time amount
        uint256 dailyAmount; // Daily payment amount
        uint256 startTime; // Start timestamp
        uint256 paidDays; // Days already paid
        uint256 totalDays; // Total days in the plan
    }

    event PaymentPlanCreated(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        address currency,
        uint256 totalDays,
        uint256 totalAmount,
        uint256 dailyAmount
    );

    event DailyPaymentReleased(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 paidDays
    );

    using SafeERC20 for IERC20;

    /// @dev payer => auto increment nonce
    mapping(address => uint256) internal _nonces;
    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;
    /// @dev payment id => payment plan
    mapping(bytes32 => PaymentPlan) internal _paymentPlans;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function getPaymentPlan(bytes32 paymentId) public view returns (PaymentPlan memory) {
        return _paymentPlans[paymentId];
    }

    function whitelistCurrency(
        address currency,
        bool status
    ) external onlyOwner {
        isCurrencyWhitelisted[currency] = status;
    }

    function createPaymentPlan(
        address payer,
        address recipient,
        address currency,
        uint256 totalAmount,
        uint256 totalDays
    ) external {
        require(isCurrencyWhitelisted[currency], "currency not whitelisted");

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, _nonces[payer]++)
        );

        IERC20(currency).safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );

        uint256 dailyAmount = totalAmount / totalDays;
        require(dailyAmount > 0, "invalid daily release amount");

        _paymentPlans[paymentId] = PaymentPlan({
            payer: payer,
            recipient: recipient,
            currency: currency,
            totalAmount: totalAmount,
            dailyAmount: dailyAmount,
            startTime: block.timestamp,
            paidDays: 0,
            totalDays: totalDays
        });

        emit PaymentPlanCreated(
            paymentId,
            payer,
            recipient,
            currency,
            totalDays,
            totalAmount,
            dailyAmount
        );
    }

    function releaseDailyPayment(bytes32 paymentId) external {
        PaymentPlan storage plan = _paymentPlans[paymentId];

        require(plan.totalAmount > 0, "no payment plan found");
        require(plan.paidDays < plan.totalDays, "all payments have been made");

        uint256 lastReleaseAt = plan.startTime + plan.paidDays * 1 days;
        uint256 passedDays = (block.timestamp - lastReleaseAt) / 1 days;

        require(passedDays > 0, "not yet time for the next payment");

        // Determine the actual days to pay without exceeding totalDays
        uint256 daysToPay = (plan.paidDays + passedDays > plan.totalDays)
            ? plan.totalDays - plan.paidDays
            : passedDays;

        // If this is the final payment, transfer the remaining balance to avoid overpayment
        uint256 amountToTransfer = (plan.paidDays + daysToPay == plan.totalDays)
            ? plan.totalAmount - plan.paidDays * plan.dailyAmount
            : plan.dailyAmount * daysToPay;

        plan.paidDays += daysToPay;

        IERC20(plan.currency).safeTransfer(plan.recipient, amountToTransfer);

        emit DailyPaymentReleased(paymentId, plan.payer, plan.recipient, plan.paidDays);
    }
}
