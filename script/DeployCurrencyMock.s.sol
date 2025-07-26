// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {CurrencyMock} from "../test/mocks/CurrencyMock.sol";

contract DeployCurrencyMock is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    address initialOwner = deployer;
    address initialTreasury = deployer;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        CurrencyMock usdt = new CurrencyMock("Tether USD", "USDT", 6);
        CurrencyMock usdc = new CurrencyMock("USDC", "USDC", 6);
        CurrencyMock veJct = new CurrencyMock("ve Janction Token", "veJCT", 18);

        usdt.mint(deployer, 10000 ether);
        usdc.mint(deployer, 10000 ether);
        veJct.mint(deployer, 10000000 ether);

        console.log("USDT:", address(usdt));
        console.log("USDC:", address(usdc));
        console.log("veJCT:", address(veJct));

        vm.stopBroadcast();
    }
}