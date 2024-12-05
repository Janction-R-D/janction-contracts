// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JanctionNFT.sol";

contract DeployJanctionNFT is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    string name = "";
    string symbol = "";

    function run() external {
        vm.startBroadcast();

        address initialOwner = deployer;
        new JanctionNFT(name, symbol, initialOwner);

        vm.stopBroadcast();
    }
}
