// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";

contract DeployPayment is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
    address deployer = vm.addr(deployerPrivateKey);
    address initialOwner = deployer;
    address initialAdmin = 0x1cAA4472af8CD33eDD589a6Fb6e787C61f97c0ce;
    uint256 threshold = 2;  // 2/3
    address usdt = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    address usdc = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    // address jct = 0xa780e5799805eCF2c8aaebf551180F8109139B38;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        PaymentImpl paymentImpl = new PaymentImpl();

        ERC1967Proxy paymentProxy = new ERC1967Proxy(address(paymentImpl), abi.encodeWithSelector(
            PaymentImpl.initialize.selector,
            initialOwner,
            initialAdmin,
            threshold
        ));

        PaymentImpl(address(paymentProxy)).whitelistCurrency(address(usdt), true);
        PaymentImpl(address(paymentProxy)).whitelistCurrency(address(usdc), true);
        // PaymentImpl(address(paymentProxy)).whitelistCurrency(address(jct), true);

        console.log("PaymentImpl:", address(paymentImpl));
        console.log("PaymentProxy:", address(paymentProxy));

        vm.stopBroadcast();
    }
}