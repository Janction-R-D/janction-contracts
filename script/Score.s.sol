// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/Score.sol";

contract DeployScore is Script {
    function run() external {
        vm.startBroadcast();

        address initialOwner = msg.sender;
        Score score = new Score(initialOwner);

        vm.stopBroadcast();
    }
}