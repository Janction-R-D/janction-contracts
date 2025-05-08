// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";

contract DeployPayment is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    address initialOwner = deployer;
    uint256 threshold = 2;  // 2/3
    address usdt = 0xCA181238E466Fd450AbCCFc8eaADECA3646e7b99;
    address usdc = 0x1123904310D41b95e30747E9687Bb167eB370547;
    address jct = 0xa780e5799805eCF2c8aaebf551180F8109139B38;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        PaymentImpl paymentImpl = new PaymentImpl();

        ERC1967Proxy paymentProxy = new ERC1967Proxy(address(paymentImpl), abi.encodeWithSelector(
            PaymentImpl.initialize.selector,
            initialOwner,
            threshold
        ));

        PaymentImpl(address(paymentProxy)).whitelistCurrency(address(usdt), true);
        PaymentImpl(address(paymentProxy)).whitelistCurrency(address(usdc), true);
        PaymentImpl(address(paymentProxy)).whitelistCurrency(address(jct), true);

        console.log("PaymentImpl:", address(paymentImpl));
        console.log("PaymentProxy:", address(paymentProxy));

        vm.stopBroadcast();
    }
}