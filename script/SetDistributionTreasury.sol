// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Distribution} from "../src/Distribution.sol";

contract SetDistributionTreasury is Script {
    Distribution distribution;
    address treasury;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        distribution.setTreasury(treasury);
        vm.stopBroadcast();
    }
}