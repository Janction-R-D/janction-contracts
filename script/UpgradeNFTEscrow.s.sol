// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NFTEscrowImpl} from "../src/NFTEscrowImpl.sol";

contract UpgradeNFTEscrow is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    NFTEscrowImpl nftEscrowProxy = NFTEscrowImpl(0x75A5FCe7F34c120d8783c6AEC4d5a5063f51846B);

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        NFTEscrowImpl nftEscrowImpl = new NFTEscrowImpl();
        nftEscrowProxy.upgradeToAndCall(address(nftEscrowImpl), new bytes(0));

        console.log("NFTEscrowImpl:", address(nftEscrowImpl));

        vm.stopBroadcast();
    }
}