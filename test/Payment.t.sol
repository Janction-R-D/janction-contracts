// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {Payment} from "../src/Payment.sol";
import {SingleFeedPriceOracle} from "../src/oracle/SingleFeedPriceOracle.sol";
import {TestCurrency} from "./mocks/TestCurrency.sol";

contract PaymentTest is Test {
    Payment payment;
    TestCurrency usdt;
    TestCurrency usdc;
    TestCurrency jct;
    SingleFeedPriceOracle usdtOracle;
    SingleFeedPriceOracle usdcOracle;
    SingleFeedPriceOracle jctOracle;

    address owner = address(0x1);
    address tenant = address(0x2);

    bytes32 nodeId = keccak256("testNode");

    function setUp() public {
        usdt = new TestCurrency("USDT", "USDT", 6);
        usdc = new TestCurrency("USDC", "USDC", 6);
        jct = new TestCurrency("ve JCT", "veJCT", 18);

        usdtOracle = new SingleFeedPriceOracle(owner);
        usdcOracle = new SingleFeedPriceOracle(owner);
        jctOracle = new SingleFeedPriceOracle(owner);

        vm.prank(owner);
        usdtOracle.setPrice(1e18); // USDT = 1 USD
        vm.prank(owner);
        usdcOracle.setPrice(1e18); // USDC = 1 USD
        vm.prank(owner);
        jctOracle.setPrice(0.5e18); // JCT = 0.5 USD

        payment = new Payment(owner);

        vm.prank(owner);
        payment.whitelistCurrency(address(usdt), true);
        vm.prank(owner);
        payment.whitelistCurrency(address(usdc), true);
        vm.prank(owner);
        payment.whitelistCurrency(address(jct), true);

        vm.prank(owner);
        payment.setPriceOracle(address(usdt), address(usdtOracle));
        vm.prank(owner);
        payment.setPriceOracle(address(usdc), address(usdcOracle));
        vm.prank(owner);
        payment.setPriceOracle(address(jct), address(jctOracle));
    }

    function testListAndRentUSDT() public {
        vm.prank(owner);
        payment.list(nodeId, 100);

        Payment.Listing memory listing = payment.getListing(owner, nodeId);
        assertEq(uint256(listing.status), uint256(Payment.ListingStatus.Listing));
        assertEq(listing.baseAmount, 100);

        uint256 totalAmount = payment.getTotalAmount(owner, nodeId, address(usdt), Payment.Duration.Month);
        usdt.mint(tenant, totalAmount);

        vm.prank(tenant);
        usdt.approve(address(payment), totalAmount);
        vm.prank(tenant);
        payment.rent(owner, nodeId, address(usdt), Payment.Duration.Month);

        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(uint256(rental.status), uint256(Payment.RentalStatus.Renting));
        assertEq(rental.currency, address(usdt));
        assertEq(rental.totalAmount, totalAmount); // 
        assertEq(rental.dailyAmount, totalAmount / uint256(30));
    }

    function testListAndRentUSDC() public {
        vm.prank(owner);
        payment.list(nodeId, 200);

        uint256 totalAmount = payment.getTotalAmount(owner, nodeId, address(usdc), Payment.Duration.Week);

        usdc.mint(tenant, totalAmount);

        vm.prank(tenant);
        usdc.approve(address(payment), totalAmount);
        vm.prank(tenant);
        payment.rent(owner, nodeId, address(usdc), Payment.Duration.Week);

        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(rental.currency, address(usdc));
        assertEq(rental.totalAmount, totalAmount); 
        assertEq(rental.dailyAmount, totalAmount / uint256(7));
    }

    function testListAndRentJCT() public {
        vm.prank(owner);
        payment.list(nodeId, 300);

        uint256 totalAmount = payment.getTotalAmount(owner, nodeId, address(jct), Payment.Duration.Quarter);
        jct.mint(tenant, totalAmount);

        vm.prank(tenant);
        jct.approve(address(payment), totalAmount);
        vm.prank(tenant);
        payment.rent(owner, nodeId, address(jct), Payment.Duration.Quarter);

        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(rental.currency, address(jct));
        assertEq(rental.totalAmount, totalAmount); 
        assertEq(rental.dailyAmount, totalAmount / uint256(120));
    }

    function testDailyPaymentRelease() public {
        vm.prank(owner);
        payment.list(nodeId, 50);

        uint256 totalAmount = payment.getTotalAmount(owner, nodeId, address(usdt), Payment.Duration.Day);

        usdt.mint(tenant, totalAmount);
        vm.prank(tenant);
        usdt.approve(address(payment), totalAmount);
        vm.prank(tenant);
        payment.rent(owner, nodeId, address(usdt), Payment.Duration.Day);

        skip(1 days);

        vm.prank(tenant);
        payment.releaseDailyPayment(owner, nodeId);

        Payment.Rental memory rental = payment.getRental(owner, nodeId);
        assertEq(rental.paidDays, 1);
        assertEq(uint256(rental.status), uint(Payment.RentalStatus.NotRent));
    }
}
