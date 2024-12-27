// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {CurrencyMock} from "./mocks/CurrencyMock.sol";
import {JasmyRewards} from "../src/JasmyRewards.sol";

contract JasmyRewardsTest is Test {
    CurrencyMock internal jasmyToken;
    JasmyRewards internal jasmyRewards;

    address internal owner = address(0x1);
    address internal user1 = address(0x2);
    address internal user2 = address(0x3);

    function setUp() public {
        jasmyToken = new CurrencyMock("JasmyToken", "JASMY", 18);

        vm.prank(owner); // 模拟 owner 部署
        jasmyRewards = new JasmyRewards(owner, address(jasmyToken));

        jasmyToken.mint(address(jasmyRewards), 1_000_000 ether);
    }

    function testUpdateRewards() public {
        vm.prank(owner);
        jasmyRewards.updateRewards(user1, 100 ether);

        // 检查奖励是否更新
        assertEq(jasmyRewards.getRewardsBy(user1), 100 ether);
    }

    function testBatchUpdateRewards() public {
        address[] memory accounts = new address[](2);
        uint256[] memory rewards = new uint256[](2);

        accounts[0] = user1;
        accounts[1] = user2;
        rewards[0] = 100 ether;
        rewards[1] = 200 ether;

        vm.prank(owner);
        jasmyRewards.batchUpdateRewards(accounts, rewards);

        assertEq(jasmyRewards.getRewardsBy(user1), 100 ether);
        assertEq(jasmyRewards.getRewardsBy(user2), 200 ether);
    }

    function testClaim() public {
        vm.prank(owner);
        jasmyRewards.updateRewards(user1, 100 ether);

        vm.prank(user1);
        jasmyRewards.claim();

        assertEq(jasmyToken.balanceOf(user1), 100 ether);

        assertEq(jasmyRewards.getRewardsBy(user1), 0);
    }

    function testWithdraw() public {
        vm.prank(owner);
        jasmyRewards.withdraw(owner, address(jasmyToken), 500_000 ether);

        assertEq(jasmyToken.balanceOf(owner), 500_000 ether);
        assertEq(jasmyToken.balanceOf(address(jasmyRewards)), 500_000 ether);
    }

    function testBatchUpdateRewardsRevert() public {
        address[] memory accounts = new address[](2);
        uint256[] memory rewards = new uint256[](1);

        accounts[0] = user1;
        accounts[1] = user2;
        rewards[0] = 100 ether;

        vm.prank(owner);
        vm.expectRevert(JasmyRewards.ArrayLengthMustBeEqual.selector);
        jasmyRewards.batchUpdateRewards(accounts, rewards);
    }
}
