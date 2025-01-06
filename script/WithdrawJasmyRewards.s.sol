// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JasmyRewards.sol";

contract WithdrawJasmyRewards is Script {
    uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
    address signer = vm.addr(signerPrivateKey);
    JasmyRewards jasmyRewards = JasmyRewards(0x38bD30C4Ce1aC8E4feEB16EF5e689B9da9207aDe);

    function run() external {
        vm.startBroadcast(signerPrivateKey);
        jasmyRewards.withdraw(signer, 1 ether);
        vm.stopBroadcast();
    }
}
