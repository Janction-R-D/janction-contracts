// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/JasmyRewards.sol";
import {CurrencyMock} from "../test/mocks/CurrencyMock.sol";

contract DeployJasmyRewards is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    address jasmyToken;
    uint256 maxDistributeAmount = 100_000 ether;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        CurrencyMock cur = new CurrencyMock("JasmyCoin", "JASMY", 18);
        console.log("jasmy:", address(cur));
        jasmyToken = address(cur);

        address initialOwner = deployer;
        address administrator = 0x1cAA4472af8CD33eDD589a6Fb6e787C61f97c0ce;
        JasmyRewards jasmyRewards = new JasmyRewards(initialOwner, administrator, jasmyToken, maxDistributeAmount);
        console.log("jasmyRewards:", address(jasmyRewards));

        cur.mint(address(jasmyRewards), 500_000 ether);

        vm.stopBroadcast();
    }
}
