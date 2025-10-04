// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PaymentImpl is UUPSUpgradeable, OwnableUpgradeable, EIP712Upgradeable {
    using SafeERC20 for IERC20;

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
        uint256 hourlyAmount; // Hourly payment amount
        uint256 startTime; // Start timestamp
        uint256 paidHours; // Hours already paid
        uint256 totalHours; // Total hours in the plan
        bytes32 data; // item id
    }

    event PaymentPlanCreated(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        address currency,
        uint256 totalHours,
        uint256 totalAmount,
        uint256 hourlyAmount,
        bytes32 data
    );

    event PaymentPlanStopped(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 refundedAmount
    );

    event HourlyPaymentReleased(
        bytes32 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint256 paidHours
    );

    bytes32 public constant STOP_PAYMENT_PLAN_TYPEHASH =
        keccak256(bytes("StopPaymentPlan(bytes32 paymentId,uint256 deadline)"));

    uint256 public constant BASIS_POINTS = 10000;

    address internal _administrator;

    address internal _treasury;

    uint256 public signatureThreshold;

    uint256 public feePoints;

    uint256 public purchaseInterval;

    /// @dev payer => auto increment nonce
    mapping(address => uint256) internal _nonces;

    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    /// @dev payment id => payment plan
    mapping(bytes32 => PaymentPlan) internal _paymentPlans;

    /// @dev item data => last purchase time
    mapping(bytes32 => uint256) public lastPurchaseTime;

    constructor() {
        _disableInitializers();
    }

    modifier onlyAdmin() {
        require(msg.sender == _administrator, "only admin");
        _;
    }

    function initialize(
        address initialOwner,
        address initialAdmin,
        address initialTreasury,
        uint256 initialThreshold,
        uint256 initialFeePoints,
        uint256 initialPurchaseInterval
    ) public initializer {
        __Ownable_init(initialOwner);
        __EIP712_init("PaymentImpl", "1");
        _administrator = initialAdmin;
        _treasury = initialTreasury;
        signatureThreshold = initialThreshold;
        require(
            initialFeePoints <= BASIS_POINTS,
            "fee points cannot exceed 100%"
        );
        feePoints = initialFeePoints;
        purchaseInterval = initialPurchaseInterval;
    }

    function setAdministrator(address administrator) public onlyOwner {
        _administrator = administrator;
    }

    function setTreasury(address treasury) public onlyOwner {
        _treasury = treasury;
    }

    function setFeePoints(uint256 feePoints_) public onlyOwner {
        require(feePoints_ <= BASIS_POINTS, "fee points cannot exceed 100%");
        feePoints = feePoints_;
    }

    function setPurchaseInterval(uint256 purchaseInterval_) public onlyOwner {
        purchaseInterval = purchaseInterval_;
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
        uint256 totalHours,
        bytes32 data
    ) external {
        require(isCurrencyWhitelisted[currency], "currency not whitelisted");
        require(
            block.timestamp - lastPurchaseTime[data] >= purchaseInterval,
            "item recently purchased"
        );

        bytes32 paymentId = keccak256(
            abi.encodePacked(payer, recipient, _nonces[payer]++)
        );

        IERC20(currency).safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );

        uint256 hourlyAmount = totalAmount / totalHours;
        require(hourlyAmount > 0, "invalid hourly release amount");

        _paymentPlans[paymentId] = PaymentPlan({
            stopped: false,
            payer: payer,
            recipient: recipient,
            currency: currency,
            totalAmount: totalAmount,
            hourlyAmount: hourlyAmount,
            startTime: block.timestamp,
            paidHours: 0,
            totalHours: totalHours,
            data: data
        });

        lastPurchaseTime[data] = block.timestamp;

        emit PaymentPlanCreated(
            paymentId,
            payer,
            recipient,
            currency,
            totalHours,
            totalAmount,
            hourlyAmount,
            data
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

        try this.releaseHourlyPayment(paymentId) {} catch {}

        uint256 remainingBalance = 0;
        if (plan.paidHours < plan.totalHours) {
            remainingBalance =
                plan.totalAmount -
                plan.paidHours *
                plan.hourlyAmount;
        }

        if (remainingBalance > 0) {
            IERC20(plan.currency).safeTransfer(plan.payer, remainingBalance);
        }

        plan.stopped = true;

        emit PaymentPlanStopped(
            paymentId,
            plan.payer,
            plan.recipient,
            remainingBalance
        );
    }

    function stopPaymentPlanAdmin(bytes32 paymentId) external onlyAdmin {
        PaymentPlan storage plan = _paymentPlans[paymentId];
        require(plan.totalAmount > 0, "no payment plan found");
        require(!plan.stopped, "payment has already stopped");

        // Try to release any due hourly payment before stopping
        try this.releaseHourlyPayment(paymentId) {} catch {}

        uint256 remainingBalance = 0;
        if (plan.paidHours < plan.totalHours) {
            remainingBalance =
                plan.totalAmount -
                plan.paidHours *
                plan.hourlyAmount;
        }

        if (remainingBalance > 0) {
            IERC20(plan.currency).safeTransfer(plan.payer, remainingBalance);
        }

        plan.stopped = true;

        emit PaymentPlanStopped(
            paymentId,
            plan.payer,
            plan.recipient,
            remainingBalance
        );
    }

    function releaseHourlyPayment(bytes32 paymentId) external {
        PaymentPlan storage plan = _paymentPlans[paymentId];

        require(plan.totalAmount > 0, "no payment plan found");
        require(
            plan.paidHours < plan.totalHours,
            "all payments have been made"
        );
        require(!plan.stopped, "payment has already stopped");

        uint256 lastReleaseAt = plan.startTime + plan.paidHours * 1 hours;
        uint256 passedHours = (block.timestamp - lastReleaseAt) / 1 hours;

        require(passedHours > 0, "not yet time for the next payment");

        // Determine the actual hours to pay without exceeding totalHours
        uint256 hoursToPay = (plan.paidHours + passedHours > plan.totalHours)
            ? plan.totalHours - plan.paidHours
            : passedHours;

        // If this is the final payment, transfer the remaining balance to avoid overpayment
        uint256 amountToTransfer = (plan.paidHours + hoursToPay ==
            plan.totalHours)
            ? plan.totalAmount - plan.paidHours * plan.hourlyAmount
            : plan.hourlyAmount * hoursToPay;

        plan.paidHours += hoursToPay;

        uint256 fee = (amountToTransfer * feePoints) / BASIS_POINTS;

        uint256 remaining = amountToTransfer - fee;

        IERC20(plan.currency).safeTransfer(_treasury, fee);

        IERC20(plan.currency).safeTransfer(plan.recipient, remaining);

        emit HourlyPaymentReleased(
            paymentId,
            plan.payer,
            plan.recipient,
            plan.paidHours
        );
    }

    function batchReleaseHourlyPayment(bytes32[] memory paymentIds) external {
        for (uint256 i = 0; i < paymentIds.length; i++) {
            // Use try/catch to avoid revert on one payment blocking all
            try this.releaseHourlyPayment(paymentIds[i]) {} catch {}
        }
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
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

    function _recoverEIP712Signer(
        bytes32 digest,
        EIP712Signature memory signature
    ) internal view returns (address) {
        require(block.timestamp < signature.deadline, "signature expired");
        address recoveredAddress = ECDSA.recover(
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
