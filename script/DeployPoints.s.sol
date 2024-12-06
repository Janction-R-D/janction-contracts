// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/Points.sol";

contract DeployPoints is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        new Points(initialOwner);

        vm.stopBroadcast();
    }
}
