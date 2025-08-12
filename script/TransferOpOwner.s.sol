// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PaymentImpl} from "../src/PaymentImpl.sol";
// import {NFTEscrowImpl} from "../src/NFTEscrowImpl.sol";
import {JanctionNFT} from "../src/JanctionNFT.sol";
import {Distribution} from "../src/Distribution.sol";

contract TransferOpOwner is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    // NFTEscrowImpl nftEscrowProxy = NFTEscrowImpl(0x75A5FCe7F34c120d8783c6AEC4d5a5063f51846B); // Replace with actual address
    PaymentImpl paymentProxy = PaymentImpl(0x225820A1CBD1A9188c3E66B23A28425e68342616);
    JanctionNFT janctionNFT = JanctionNFT(0x437ec4194ee2EFdBF326fD16ebaa29418CF8c451);
    Distribution distribution = Distribution(0x78529A764A77325933dB1f22C26f8833a725df2d); // Replace with actual address
    address newOwner = 0xdb603e5b2169385385e294e3C1984E55530d454A;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        distribution.transferOwnership(newOwner);
        paymentProxy.transferOwnership(newOwner);
        janctionNFT.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
