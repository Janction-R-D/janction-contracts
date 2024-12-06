// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JanctionNFT.sol";

contract Mint is Script {
    JanctionNFT nft = JanctionNFT(0x6f899dA8D3d9De3A910Ee38773444B757D1Cf197);
    uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
    address signer = vm.addr(signerPrivateKey);
    address to = 0xD0167B1cc6CAb1e4e7C6f38d09EA35171d00b68e;

    function run() external {
        vm.startBroadcast(signerPrivateKey);

        nft.mint(to);

        vm.stopBroadcast();
    }
}
