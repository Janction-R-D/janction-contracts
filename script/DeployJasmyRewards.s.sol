// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JasmyRewards.sol";

contract DeployJasmyRewards is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    address jasmyToken = 0x7420B4b9a0110cdC71fB720908340C03F9Bc03EC;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        address administrator = 0x1cAA4472af8CD33eDD589a6Fb6e787C61f97c0ce;
        JasmyRewards jasmyRewards = new JasmyRewards(initialOwner, administrator, jasmyToken);
        console.log("jasmyRewards:", address(jasmyRewards));

        vm.stopBroadcast();
    }
}
