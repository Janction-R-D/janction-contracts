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
    address initialTreasury = 0x36302f71d74d62CC7A3eB7b79af1332A0A33e46C;
    uint256 threshold = 2; // 2/3
    uint256 initialFeePoints = 500; // 5%
    uint256 initialPurchaseInterval = 10; // 10 seconds

    // op
    // address usdt = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    // address usdc = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

    // op_sepolia
    // address usdt = 0xCA181238E466Fd450AbCCFc8eaADECA3646e7b99;
    // address usdc = 0x1123904310D41b95e30747E9687Bb167eB370547;

    // jasmy_testnet
    address usdt = 0x4be5136fE3E5c908183ec56A55C5A8fE6896faf2;
    address usdc = 0xEce3d97486783b5a6E32B49c122EC3A5b73dd064;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        PaymentImpl paymentImpl = new PaymentImpl();

        ERC1967Proxy paymentProxy = new ERC1967Proxy(
            address(paymentImpl),
            abi.encodeWithSelector(
                PaymentImpl.initialize.selector,
                initialOwner,
                initialAdmin,
                initialTreasury,
                threshold,
                initialFeePoints,
                initialPurchaseInterval
            )
        );

        PaymentImpl(address(paymentProxy)).whitelistCurrency(
            address(usdt),
            true
        );
        PaymentImpl(address(paymentProxy)).whitelistCurrency(
            address(usdc),
            true
        );
        // PaymentImpl(address(paymentProxy)).whitelistCurrency(address(jct), true);

        console.log("PaymentImpl:", address(paymentImpl));
        console.log("PaymentProxy:", address(paymentProxy));

        vm.stopBroadcast();
    }
}
