// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Distribution} from "../src/Distribution.sol";

contract DeployDistribution is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        address initialTreasury = deployer;
        Distribution distribution = new Distribution(initialOwner, initialTreasury);

        address usdt = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;

        distribution.whitelistCurrency(usdt, true);

        console.log("Distribution:", address(distribution));

        vm.stopBroadcast();
    }
}