// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PaymentImplV2} from "../src/PaymentImplV2.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";

contract UpgradePaymentV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddr = address(0xC81bD9Aa97Cd31F6F6C6e678f856C7eFC123c40e);

        vm.startBroadcast(deployerPrivateKey);

        // 部署新实现
        PaymentImplV2 v2 = new PaymentImplV2();
        // 升级（data 为空即可）
        PaymentImpl(proxyAddr).upgradeToAndCall(address(v2), "");

        console.log("PaymentImplV2:", address(v2));
        console.log("PaymentProxy:", proxyAddr);

        vm.stopBroadcast();
    }
} 