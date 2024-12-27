// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JasmyRewards.sol";
import {CurrencyMock} from "../test/mocks/CurrencyMock.sol";

contract DeployJasmyRewards is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    CurrencyMock jasmyToken = CurrencyMock(0x630381D207a35D2498178A849C3Cd04d5B33eE03);

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        JasmyRewards jasmyRewards = new JasmyRewards(initialOwner, address(jasmyToken));
        console.log("jasmyRewards:", address(jasmyRewards));

        jasmyToken.mint(address(jasmyRewards), 10000000000000 ether);

        vm.stopBroadcast();
    }
}
