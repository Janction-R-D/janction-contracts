// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PaymentImpl is UUPSUpgradeable, OwnableUpgradeable, EIP712Upgradeable {
    using SafeERC20 for IERC20;

    enum TimeGranularity {
        DAYS,
        HOURS
    }

    struct EIP712Signature {
        address signer;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    struct PaymentPlan {
        bool stopped; // stop status
        address payer; // payer address
        address recipient; // recipient address
        address currency; // payment currency
        uint256 totalAmount; // Total one-time amount
        uint256 periodAmount; // Amount per period (day/hour)
        uint256 startTime; // Start timestamp
        uint256 paidPeriods; // Periods already paid
        uint256 totalPeriods; // Total periods in the plan
        TimeGranularity granularity; // Time granularity for payments
    }

    event PaymentPlanCreated(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        address currency,
        uint256 totalPeriods,
        uint256 totalAmount,
        uint256 periodAmount,
        TimeGranularity granularity
    );

    event PaymentPlanStopped(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 refundedAmount
    );

    event PeriodPaymentReleased(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 paidPeriods
    );

    bytes32 public constant STOP_PAYMENT_PLAN_TYPEHASH =
        keccak256(bytes("StopPaymentPlan(bytes32 paymentId,uint256 deadline)"));

    address internal _administrator;

    uint256 public signatureThreshold;

    /// @dev payer => auto increment nonce
    mapping(address => uint256) internal _nonces;

    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    /// @dev payment id => payment plan
    mapping(bytes32 => PaymentPlan) internal _paymentPlans;

    function initialize(
        address initialOwner,
        address administrator,
        uint256 threshold
    ) public initializer {
        __Ownable_init(initialOwner);
        __EIP712_init("PaymentImpl", "1");
        _administrator = administrator;
        signatureThreshold = threshold;
    }

    function setAdministrator(address administrator) public onlyOwner {
        _administrator = administrator;
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
        uint256 totalPeriods,
        TimeGranularity granularity
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

        require(totalPeriods > 0, "total periods must be greater than zero");

        uint256 periodAmount = totalAmount / totalPeriods;
        require(periodAmount > 0, "period release amount must be greater than zero");

        _paymentPlans[paymentId] = PaymentPlan({
            stopped: false,
            payer: payer,
            recipient: recipient,
            currency: currency,
            totalAmount: totalAmount,
            periodAmount: periodAmount,
            startTime: block.timestamp,
            paidPeriods: 0,
            totalPeriods: totalPeriods,
            granularity: granularity
        });

        emit PaymentPlanCreated(
            paymentId,
            payer,
            recipient,
            currency,
            totalPeriods,
            totalAmount,
            periodAmount,
            granularity
        );
    }

    function stopPaymentPlan(
        bytes32 paymentId,
        EIP712Signature[] calldata signatures
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
        signers[2] = _administrator;

        uint256 validSignatures = 0;
        for (uint256 i = 0; i < signatures.length; i++) {
            address recoveredAddr = _recoverEIP712Signer(
                _hashTypedDataV4(
                    keccak256(
                        abi.encode(
                            STOP_PAYMENT_PLAN_TYPEHASH,
                            paymentId,
                            signatures[i].deadline
                        )
                    )
                ),
                signatures[i]
            );

            require(
                recoveredAddr == signatures[i].signer,
                "recovered address not equal to signer"
            );

            for (uint256 j = 0; j < signers.length; j++) {
                if (recoveredAddr == signers[j]) {
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

        try this.releasePeriodPayment(paymentId) {} catch {}

        uint256 remainingBalance = plan.totalAmount -
            plan.paidPeriods *
            plan.periodAmount;

        IERC20(plan.currency).safeTransfer(plan.payer, remainingBalance);

        plan.stopped = true;

        emit PaymentPlanStopped(
            paymentId,
            plan.payer,
            plan.recipient,
            remainingBalance
        );
    }

    function releasePeriodPayment(bytes32 paymentId) external {
        PaymentPlan storage plan = _paymentPlans[paymentId];

        require(plan.totalAmount > 0, "no payment plan found");
        require(
            plan.paidPeriods < plan.totalPeriods,
            "all payments have been made"
        );
        require(!plan.stopped, "payment has already stopped");

        uint256 periodDuration = (plan.granularity == TimeGranularity.DAYS)
            ? 1 days
            : 1 hours;
        uint256 lastReleaseAt = plan.startTime +
            plan.paidPeriods *
            periodDuration;
        uint256 passedPeriods = (block.timestamp - lastReleaseAt) /
            periodDuration;

        require(passedPeriods > 0, "not yet time for the next payment");

        // Determine the actual periods to pay without exceeding totalPeriods
        uint256 periodsToPay = (plan.paidPeriods + passedPeriods >
            plan.totalPeriods)
            ? plan.totalPeriods - plan.paidPeriods
            : passedPeriods;

        // If this is the final payment, transfer the remaining balance to avoid overpayment
        uint256 amountToTransfer = (plan.paidPeriods + periodsToPay ==
            plan.totalPeriods)
            ? plan.totalAmount - plan.paidPeriods * plan.periodAmount
            : plan.periodAmount * periodsToPay;

        plan.paidPeriods += periodsToPay;

        IERC20(plan.currency).safeTransfer(plan.recipient, amountToTransfer);

        emit PeriodPaymentReleased(
            paymentId,
            plan.payer,
            plan.recipient,
            plan.paidPeriods
        );
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _recoverEIP712Signer(
        bytes32 digest,
        EIP712Signature memory signature
    ) internal view returns (address) {
        require(block.timestamp < signature.deadline, "signature expired");
        address recoveredAddress = ecrecover(
            digest,
            signature.v,
            signature.r,
            signature.s
        );
        return recoveredAddress;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}
