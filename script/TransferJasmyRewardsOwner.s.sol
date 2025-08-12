// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JasmyRewards.sol";

contract TransferJasmyRewardsOwner is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    JasmyRewards jasmyRewards = JasmyRewards(0x38bD30C4Ce1aC8E4feEB16EF5e689B9da9207aDe);
    address newOwner = 0xdb603e5b2169385385e294e3C1984E55530d454A;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        jasmyRewards.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
