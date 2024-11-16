// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/Payment.sol";
import {TestCurrency} from "../test/mocks/TestCurrency.sol";

contract DeployPayment is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TestCurrency currency = new TestCurrency();

        address initialOwner = deployer;
        Payment payment = new Payment(initialOwner);

        payment.whitelistCurrency(address(currency), true);

        uint256 baseAmount = 10;
        payment.createPayeeListing(address(currency), baseAmount);

        uint256 totalAmount = payment.getTotalAmount(deployer, Payment.Duration.Week);
        currency.mint(deployer, totalAmount);
        currency.approve(address(payment), totalAmount);

        payment.createPayerPlan(deployer, Payment.Duration.Week);

        vm.stopBroadcast();
    }
}