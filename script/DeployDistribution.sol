// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {Distribution} from "../src/Distribution.sol";
import {CurrencyMock} from "../test/mocks/CurrencyMock.sol";

contract DeployDistribution is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        address initialOwner = deployer;
        Distribution distribution = new Distribution(initialOwner);

        CurrencyMock usdt = CurrencyMock(0xCA181238E466Fd450AbCCFc8eaADECA3646e7b99);
        CurrencyMock usdc = CurrencyMock(0x1123904310D41b95e30747E9687Bb167eB370547);
        CurrencyMock jct = CurrencyMock(0xa780e5799805eCF2c8aaebf551180F8109139B38);

        distribution.whitelistCurrency(address(usdt), true);
        distribution.whitelistCurrency(address(usdc), true);
        distribution.whitelistCurrency(address(jct), true);

        console.log("Distribution:", address(distribution));

        vm.stopBroadcast();
    }
}