// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";

contract UpgradePayment is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    PaymentImpl paymentProxy = PaymentImpl(0xBb24a1f7EB4afB95Abf92967A35327CeaFAA5610);

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        PaymentImpl paymentImpl = new PaymentImpl();
        paymentProxy.upgradeToAndCall(address(paymentImpl), new bytes(0));

        console.log("PaymentImpl:", address(paymentImpl));

        vm.stopBroadcast();
    }
}