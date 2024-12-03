// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Payment} from "../src/Payment.sol";
import {TestCurrency} from "../test/mocks/TestCurrency.sol";
import {SingleFeedPriceOracle} from "../src/oracle/SingleFeedPriceOracle.sol";

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

        // SingleFeedPriceOracle usdtOracle = new SingleFeedPriceOracle(deployer);
        // SingleFeedPriceOracle usdcOracle = new SingleFeedPriceOracle(deployer);
        // SingleFeedPriceOracle jctOracle = new SingleFeedPriceOracle(deployer);
        // usdtOracle.setPrice(1e18); // USDT = 1 USD
        // usdcOracle.setPrice(1e18); // USDC = 1 USD
        // jctOracle.setPrice(0.5e18); // JCT = 0.5 USD

        TestCurrency usdt = TestCurrency(0xCA181238E466Fd450AbCCFc8eaADECA3646e7b99);
        TestCurrency usdc = TestCurrency(0x1123904310D41b95e30747E9687Bb167eB370547);
        TestCurrency jct = TestCurrency(0xa780e5799805eCF2c8aaebf551180F8109139B38);
        SingleFeedPriceOracle usdtOracle = SingleFeedPriceOracle(0x31c876b373a9Dd35B164ba626c702E8BCdE58082);
        SingleFeedPriceOracle usdcOracle = SingleFeedPriceOracle(0x9d7CB65110A02432423cE0775b09dfB66859baaF);
        SingleFeedPriceOracle jctOracle = SingleFeedPriceOracle(0xD9BeFA1c7da2891CAb652AB9f163340545177fbD);

        payment.whitelistCurrency(address(usdt), true);
        payment.whitelistCurrency(address(usdc), true);
        payment.whitelistCurrency(address(jct), true);

        payment.setPriceOracle(address(usdt), address(usdtOracle));
        payment.setPriceOracle(address(usdc), address(usdcOracle));
        payment.setPriceOracle(address(jct), address(jctOracle));

        // console.log("USDT:", address(usdt));
        // console.log("USDC:", address(usdc));
        // console.log("JCT:", address(jct));
        // console.log("USDTPriceOracle:", address(usdtOracle));
        // console.log("USDCPriceOracle:", address(usdcOracle));
        // console.log("JCTPriceOracle:", address(jctOracle));
        console.log("Payment:", address(payment));

        vm.stopBroadcast();
    }
}