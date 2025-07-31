// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PaymentImplV3} from "../src/PaymentImplV3.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";

contract UpgradePaymentV3 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
        address proxyAddr = address(0x4ab38a24d7C71D000510F3b8E7b393e6337029Ce);

        vm.startBroadcast(deployerPrivateKey);

        // 部署新实现
        PaymentImplV3 v3 = new PaymentImplV3();
        // 升级（data 为空即可）
        PaymentImpl(proxyAddr).upgradeToAndCall(address(v3), "");

        console.log("PaymentImplV3:", address(v3));
        console.log("PaymentProxy:", proxyAddr);

        vm.stopBroadcast();
    }
} 