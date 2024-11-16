// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Payment is Ownable {
    enum Duration {
        Day,
        Week,
        Month,
        Quarter
    }

    enum PaymentStatus {
        Available,
        Locked
    }

    struct PayerPlan {
        PaymentStatus status;
        address currency;   // payment currency
        uint256 totalAmount; // Total one-time amount
        uint256 dailyAmount; // Daily payment amount
        uint256 startTime; // Start timestamp
        uint256 paidDays; // Days already paid
        uint256 totalDays; // Total days in the plan
    }

    struct PayeeListing {
        address currency;
        uint256 baseAmount;
    }

    using SafeERC20 for IERC20;

    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;
    /// @dev payee => listing
    mapping(address => PayeeListing) public payeeListings;
    /// @dev payee => payer's payment plan
    mapping(address => PayerPlan) public payerPlans;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function whitelistCurrency(
        address currency,
        bool status
    ) external onlyOwner {
        isCurrencyWhitelisted[currency] = status;
    }

    function createPayeeListing(address currency, uint256 baseAmount) external {
        require(isCurrencyWhitelisted[currency], "currency not whitelisted");
        payeeListings[msg.sender] = PayeeListing({
            currency: currency,
            baseAmount: baseAmount
        });
    }

    function createPayerPlan(address payee, Duration duration) external {
        PayeeListing storage listing = payeeListings[payee];
        PayerPlan storage plan = payerPlans[payee];

        require(
            plan.status == PaymentStatus.Available,
            "payment status not available"
        );

        uint256 totalAmount = getTotalAmount(payee, duration);
        IERC20(listing.currency).safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );

        uint256 totalDays = _durationDays(duration);
        uint256 dailyAmount = totalAmount / totalDays;

        payerPlans[payee] = PayerPlan({
            status: PaymentStatus.Locked,
            currency: listing.currency,
            totalAmount: totalAmount,
            dailyAmount: dailyAmount,
            startTime: block.timestamp,
            paidDays: 0,
            totalDays: totalDays
        });
    }

    function releaseDailyPayment(address payee) external {
        PayerPlan storage plan = payerPlans[payee];

        require(plan.totalAmount > 0, "no payment plan found for this payee");
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

        IERC20(plan.currency).safeTransfer(payee, amountToTransfer);

        if (plan.paidDays == plan.totalDays) {
            plan.status = PaymentStatus.Available;
        }
    }

    function getTotalAmount(
        address payee,
        Duration duration
    ) public view returns (uint256) {
        uint256 multiplier = _durationMultiplier(duration);
        return multiplier * payeeListings[payee].baseAmount;
    }

    function _durationMultiplier(
        Duration duration
    ) internal pure returns (uint256) {
        if (duration == Duration.Day) {
            return 1;
        } else if (duration == Duration.Week) {
            return 6;
        } else if (duration == Duration.Month) {
            return 25;
        } else if (duration == Duration.Quarter) {
            return 70;
        } else {
            revert("invalid duration");
        }
    }

    function _durationDays(Duration duration) internal pure returns (uint256) {
        if (duration == Duration.Day) {
            return 1;
        } else if (duration == Duration.Week) {
            return 7;
        } else if (duration == Duration.Month) {
            return 30;
        } else if (duration == Duration.Quarter) {
            return 120;
        } else {
            revert("invalid duration");
        }
    }
}
