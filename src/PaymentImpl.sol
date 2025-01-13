// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PaymentImpl is UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    struct PaymentPlan {
        bool stopped; // stop status
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

    event PaymentPlanStopped(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 refundedAmount
    );

    event DailyPaymentReleased(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 paidDays
    );

    uint256 public signatureThreshold;
    /// @dev payer => auto increment nonce
    mapping(address => uint256) internal _nonces;
    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;
    /// @dev payment id => payment plan
    mapping(bytes32 => PaymentPlan) internal _paymentPlans;

    function initialize(
        address initialOwner,
        uint256 threshold
    ) public initializer {
        __Ownable_init(initialOwner);
        signatureThreshold = threshold;
    }

    function getPaymentPlan(
        bytes32 paymentId
    ) public view returns (PaymentPlan memory) {
        return _paymentPlans[paymentId];
    }

    function whitelistCurrency(
        address currency,
        bool status
    ) external onlyOwner {
        isCurrencyWhitelisted[currency] = status;
    }

    function setSignatureThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 0 && threshold <= 3, "invalid threshold");
        signatureThreshold = threshold;
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
            stopped: false,
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

    function stopPaymentPlan(
        bytes32 paymentId,
        bytes[] calldata signatures
    ) external {
        require(
            signatures.length >= signatureThreshold,
            "insufficient signatures"
        );

        PaymentPlan storage plan = _paymentPlans[paymentId];

        require(plan.totalAmount > 0, "no payment plan found");
        require(!plan.stopped, "payment has already stopped");

        address[] memory signers = new address[](3);
        signers[0] = plan.payer;
        signers[1] = plan.recipient;
        signers[2] = owner();

        uint256 validSignatures = 0;
        for (uint256 i = 0; i < signatures.length; i++) {
            bytes32 messageHash = keccak256(
                abi.encodePacked(paymentId, "STOP")
            );
            address signer = _recoverSigner(messageHash, signatures[i]);
            for (uint256 j = 0; j < signers.length; j++) {
                if (signer == signers[j]) {
                    validSignatures++;
                    signers[j] = address(0); // Prevent double-counting
                    break;
                }
            }
        }

        require(
            validSignatures >= signatureThreshold,
            "insufficient valid signatures"
        );

        try this.releaseDailyPayment(paymentId) {} catch {}

        uint256 remainingBalance = plan.totalAmount -
            plan.paidDays *
            plan.dailyAmount;

        IERC20(plan.currency).safeTransfer(plan.payer, remainingBalance);

        plan.stopped = true;

        emit PaymentPlanStopped(
            paymentId,
            plan.payer,
            plan.recipient,
            remainingBalance
        );
    }

    function releaseDailyPayment(bytes32 paymentId) external {
        PaymentPlan storage plan = _paymentPlans[paymentId];

        require(plan.totalAmount > 0, "no payment plan found");
        require(plan.paidDays < plan.totalDays, "all payments have been made");
        require(!plan.stopped, "payment has already stopped");

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

        emit DailyPaymentReleased(
            paymentId,
            plan.payer,
            plan.recipient,
            plan.paidDays
        );
    }

    function _recoverSigner(
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 prefixedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        return ecrecover(prefixedMessageHash, v, r, s);
    }

    function _splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (r, s, v);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}
