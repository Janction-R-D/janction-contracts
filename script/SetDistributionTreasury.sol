// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Distribution} from "../src/Distribution.sol";

contract SetDistributionTreasury is Script {
    Distribution distribution = Distribution(0x78529A764A77325933dB1f22C26f8833a725df2d);
    address treasury;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        distribution.setTreasury(treasury);
        vm.stopBroadcast();
    }
}