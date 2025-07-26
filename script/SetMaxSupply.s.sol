// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JanctionNFT.sol";

contract Mint is Script {
    JanctionNFT nft = JanctionNFT(0x437ec4194ee2EFdBF326fD16ebaa29418CF8c451);
    uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY1");
    address signer = vm.addr(signerPrivateKey);

    function run() external {
        vm.startBroadcast(signerPrivateKey);

        nft.setMaxSupply(5000);

        vm.stopBroadcast();
    }
}
