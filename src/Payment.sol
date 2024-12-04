// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Payment is Ownable {
    enum ListingStatus {
        NotList,
        Listing
    }

    enum RentalStatus {
        NotRent,
        Renting
    }

    struct Listing {
        ListingStatus status;
        address owner;
        uint256 baseAmount;
    }

    struct Rental {
        RentalStatus status;
        address tenant; // tenant address
        address currency; // payment currency
        uint256 totalAmount; // Total one-time amount
        uint256 dailyAmount; // Daily payment amount
        uint256 startTime; // Start timestamp
        uint256 paidDays; // Days already paid
        uint256 totalDays; // Total days in the plan
    }

    event List(
        address indexed owner,
        bytes32 indexed nodeId,
        uint256 baseAmount
    );

    event Rent(
        address indexed owner,
        bytes32 indexed nodeId,
        address indexed tenant,
        uint256 totalDays,
        uint256 totalAmount,
        uint256 dailyAmount
    );

    event DailyPaymentReleased(
        address indexed owner,
        bytes32 indexed nodeId,
        address indexed tenant,
        uint256 paidDays
    );

    using SafeERC20 for ERC20;

    /// @dev currency => is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;
    /// @dev owner => node_id => listings
    mapping(address => mapping(bytes32 => Listing)) public listings;
    /// @dev owner => node_id => rentals
    mapping(address => mapping(bytes32 => Rental)) public rentals;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function whitelistCurrency(
        address currency,
        bool status
    ) external onlyOwner {
        isCurrencyWhitelisted[currency] = status;
    }

    function list(bytes32 nodeId, uint256 baseAmount) external {
        require(
            listings[msg.sender][nodeId].status == ListingStatus.NotList,
            "node has been listed"
        );

        listings[msg.sender][nodeId] = Listing({
            status: ListingStatus.Listing,
            owner: msg.sender,
            baseAmount: baseAmount
        });

        emit List(msg.sender, nodeId, baseAmount);
    }

    function delist(bytes32 nodeId) external {
        require(
            rentals[msg.sender][nodeId].status == RentalStatus.NotRent,
            "node has tenant"
        );

        listings[msg.sender][nodeId].status = ListingStatus.NotList;
    }

    function rent(
        address owner,
        bytes32 nodeId,
        address currency,
        uint256 totalAmount,
        uint256 totalDays
    ) external {
        Listing storage listing = listings[owner][nodeId];
        Rental storage rental = rentals[owner][nodeId];

        require(listing.status == ListingStatus.Listing, "node not listing");

        require(rental.status == RentalStatus.NotRent, "node has tenant");

        require(isCurrencyWhitelisted[currency], "currency not whitelisted");

        ERC20(currency).safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );

        uint256 dailyAmount = totalAmount / totalDays;

        rentals[owner][nodeId] = Rental({
            status: RentalStatus.Renting,
            tenant: msg.sender,
            currency: currency,
            totalAmount: totalAmount,
            dailyAmount: dailyAmount,
            startTime: block.timestamp,
            paidDays: 0,
            totalDays: totalDays
        });

        emit Rent(
            owner,
            nodeId,
            msg.sender,
            totalDays,
            totalAmount,
            dailyAmount
        );
    }

    function releaseDailyPayment(address owner, bytes32 nodeId) external {
        Rental storage rental = rentals[owner][nodeId];

        require(
            rental.totalAmount > 0,
            "no payment rental found for this payee"
        );
        require(
            rental.paidDays < rental.totalDays,
            "all payments have been made"
        );

        uint256 lastReleaseAt = rental.startTime + rental.paidDays * 1 days;
        uint256 passedDays = (block.timestamp - lastReleaseAt) / 1 days;

        require(passedDays > 0, "not yet time for the next payment");

        // Determine the actual days to pay without exceeding totalDays
        uint256 daysToPay = (rental.paidDays + passedDays > rental.totalDays)
            ? rental.totalDays - rental.paidDays
            : passedDays;

        // If this is the final payment, transfer the remaining balance to avoid overpayment
        uint256 amountToTransfer = (rental.paidDays + daysToPay ==
            rental.totalDays)
            ? rental.totalAmount - rental.paidDays * rental.dailyAmount
            : rental.dailyAmount * daysToPay;

        rental.paidDays += daysToPay;

        ERC20(rental.currency).safeTransfer(owner, amountToTransfer);

        if (rental.paidDays == rental.totalDays) {
            rental.status = RentalStatus.NotRent;
        }

        emit DailyPaymentReleased(
            owner,
            nodeId,
            rental.tenant,
            rental.paidDays
        );
    }

    function getListing(
        address owner,
        bytes32 nodeId
    ) public view returns (Listing memory) {
        return listings[owner][nodeId];
    }

    function getRental(
        address owner,
        bytes32 nodeId
    ) public view returns (Rental memory) {
        return rentals[owner][nodeId];
    }
}
