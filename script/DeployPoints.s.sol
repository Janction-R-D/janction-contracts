// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/Points.sol";

contract DeployPoints is Script {
    function run() external {
        vm.startBroadcast();

        address initialOwner = msg.sender;
        new Points(initialOwner);

        vm.stopBroadcast();
    }
}