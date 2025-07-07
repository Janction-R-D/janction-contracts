// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NFTEscrowImpl} from "../src/NFTEscrowImpl.sol";


contract DeployNFTEscrow is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    address initialOwner = deployer;
    address janctionNFT = 0x248f49674A9cc39E68615BD6669F5a395cbfa4D3;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        NFTEscrowImpl nftEscrowImpl = new NFTEscrowImpl();
        ERC1967Proxy nftEscrowProxy = new ERC1967Proxy(address(nftEscrowImpl), abi.encodeWithSelector(
            NFTEscrowImpl.initialize.selector,
            initialOwner,
            janctionNFT
        ));

        console.log("NFTEscrowImpl:", address(nftEscrowImpl));
        console.log("NFTEscrowProxy:", address(nftEscrowProxy));

        vm.stopBroadcast();
    }
}