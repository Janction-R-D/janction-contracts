// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/Payment.sol";

contract DeployPayment is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        Payment payment = new Payment(initialOwner);

        payment.whitelistCurrency(0x248f49674A9cc39E68615BD6669F5a395cbfa4D3, true);

        vm.stopBroadcast();
    }
}