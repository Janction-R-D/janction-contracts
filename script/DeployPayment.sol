// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Payment} from "../src/Payment.sol";
import {TestCurrency} from "../test/mocks/TestCurrency.sol";

contract DeployPayment is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        Payment payment = new Payment(initialOwner);

        // TestCurrency usdt = new TestCurrency("USDT", "USDT", 6);
        // TestCurrency usdc = new TestCurrency("USDC", "USDC", 6);
        // TestCurrency jct = new TestCurrency("ve JCT", "veJCT", 18);
        // usdt.mint(deployer, 1e20);
        // usdc.mint(deployer, 1e20);
        // jct.mint(deployer, 1e30);

        TestCurrency usdt = TestCurrency(0xCA181238E466Fd450AbCCFc8eaADECA3646e7b99);
        TestCurrency usdc = TestCurrency(0x1123904310D41b95e30747E9687Bb167eB370547);
        TestCurrency jct = TestCurrency(0xa780e5799805eCF2c8aaebf551180F8109139B38);

        payment.whitelistCurrency(address(usdt), true);
        payment.whitelistCurrency(address(usdc), true);
        payment.whitelistCurrency(address(jct), true);

        // console.log("USDT:", address(usdt));
        // console.log("USDC:", address(usdc));
        // console.log("JCT:", address(jct));
        console.log("Payment:", address(payment));

        vm.stopBroadcast();
    }
}