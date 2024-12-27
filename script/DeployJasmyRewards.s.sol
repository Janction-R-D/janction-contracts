// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JasmyRewards.sol";
import {CurrencyMock} from "../test/mocks/CurrencyMock.sol";

contract DeployJasmyRewards is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    address jasmyToken;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        CurrencyMock token = new CurrencyMock("JasmyToken", "JASMY", 18);
        jasmyToken = address(token);
        console.log("jasmyToken:", jasmyToken);
        address initialOwner = deployer;
        JasmyRewards jasmyRewards = new JasmyRewards(initialOwner, jasmyToken);
        console.log("jasmyRewards:", address(jasmyRewards));
        token.mint(address(jasmyRewards), 10000000000000 ether);

        vm.stopBroadcast();
    }
}
