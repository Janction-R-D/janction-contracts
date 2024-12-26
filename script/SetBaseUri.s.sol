// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JanctionNFT.sol";

contract SetBaseUri is Script {
    JanctionNFT nft = JanctionNFT(0x437ec4194ee2EFdBF326fD16ebaa29418CF8c451);
    uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
    address signer = vm.addr(signerPrivateKey);
    string baseUri = "https://pub-da89859eb37b4af0ab4fbec6b5247ec5.r2.dev/";

    function run() external {
        vm.startBroadcast(signerPrivateKey);

        nft.setBaseUri(baseUri);
        console.log(nft.tokenURI(1));

        vm.stopBroadcast();
    }
}
