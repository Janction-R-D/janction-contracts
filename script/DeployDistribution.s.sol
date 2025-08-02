// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Distribution} from "../src/Distribution.sol";

contract DeployDistribution is Script {
    address initialTreasury = 0x36302f71d74d62CC7A3eB7b79af1332A0A33e46C;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        Distribution distribution = new Distribution(initialOwner, initialTreasury);

        address usdt = 0x4be5136fE3E5c908183ec56A55C5A8fE6896faf2;

        distribution.whitelistCurrency(usdt, true);

        console.log("Distribution:", address(distribution));

        vm.stopBroadcast();
    }
}