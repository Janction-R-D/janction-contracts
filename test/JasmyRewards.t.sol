// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {JasmyRewards} from "../src/JasmyRewards.sol";
import {CurrencyMock} from "./mocks/CurrencyMock.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract JasmyRewardsTest is Test, EIP712 {
    error EnforcedPause();

    JasmyRewards private jasmyRewards;
    CurrencyMock private jasmyToken;

    address private owner;
    address private administrator;
    uint256 private administratorPK;
    address private user1;
    uint256 private user1PK;
    address private user2;
    uint256 private user2PK;

    constructor() EIP712("", "") {}

    function setUp() public {
        owner = makeAddr("owner");
        (administrator, administratorPK) = makeAddrAndKey("administrator");
        (user1, user1PK) = makeAddrAndKey("user1");
        (user2, user2PK) = makeAddrAndKey("user2");

        jasmyToken = new CurrencyMock("JasmyToken", "JASMY", 18);

        jasmyRewards = new JasmyRewards(
            owner,
            administrator,
            address(jasmyToken),
            100000 ether
        );

        jasmyToken.mint(address(jasmyRewards), 1_000_000 ether);
    }

    function testPauseAndUnpause() public {
        vm.prank(owner);
        jasmyRewards.pause();

        uint256 nonce = jasmyRewards.getSigNonce(user1);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 rewards = 100 ether;

        bytes32 hashedMessage = keccak256(
            abi.encode(
                jasmyRewards.DISTRIBUTE_REWARDS_TYPEHASH(),
                user1,
                rewards,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = jasmyRewards.getDomainSeparator();

        bytes32 digest = _calculateEIP712Digest(domainSeparator, hashedMessage);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(administratorPK, digest);

        JasmyRewards.EIP712Signature memory signature = JasmyRewards
            .EIP712Signature({
                signer: administrator,
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(user1);
        jasmyRewards.distributeRewards(signature, rewards);

        vm.prank(owner);
        jasmyRewards.unpause();

        vm.prank(user1);
        jasmyRewards.distributeRewards(signature, rewards);

        assertEq(jasmyToken.balanceOf(user1), rewards);

        assertEq(
            jasmyToken.balanceOf(address(jasmyRewards)),
            1_000_000 ether - rewards
        );

        assertEq(jasmyRewards.getSigNonce(user1), nonce + 1);
    }

    function testWithdraw() public {
        vm.prank(owner);

        jasmyRewards.withdraw(owner, 500_000 ether);

        assertEq(jasmyToken.balanceOf(owner), 500_000 ether);

        assertEq(jasmyToken.balanceOf(address(jasmyRewards)), 500_000 ether);
    }

    function testDistributeRewards() public {
        uint256 nonce = jasmyRewards.getSigNonce(user1);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 rewards = 100 ether;

        bytes32 hashedMessage = keccak256(
            abi.encode(
                jasmyRewards.DISTRIBUTE_REWARDS_TYPEHASH(),
                user1,
                rewards,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = jasmyRewards.getDomainSeparator();

        bytes32 digest = _calculateEIP712Digest(domainSeparator, hashedMessage);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(administratorPK, digest);

        JasmyRewards.EIP712Signature memory signature = JasmyRewards
            .EIP712Signature({
                signer: administrator,
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });

        vm.prank(user1);
        jasmyRewards.distributeRewards(signature, rewards);

        assertEq(jasmyToken.balanceOf(user1), rewards);

        assertEq(
            jasmyToken.balanceOf(address(jasmyRewards)),
            1_000_000 ether - rewards
        );

        assertEq(jasmyRewards.getSigNonce(user1), nonce + 1);
    }

    function testDistributeRewardsWhenExceedsMaxDistributedAmount() public {
        vm.prank(owner);
        jasmyRewards.setMaxDistributeAmount(99 ether);

        uint256 nonce = jasmyRewards.getSigNonce(user1);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 rewards = 100 ether;

        bytes32 hashedMessage = keccak256(
            abi.encode(
                jasmyRewards.DISTRIBUTE_REWARDS_TYPEHASH(),
                user1,
                rewards,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = jasmyRewards.getDomainSeparator();

        bytes32 digest = _calculateEIP712Digest(domainSeparator, hashedMessage);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(administratorPK, digest);

        JasmyRewards.EIP712Signature memory signature = JasmyRewards
            .EIP712Signature({
                signer: administrator,
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });

        vm.expectRevert("distribute amount too large");
        vm.prank(user1);
        jasmyRewards.distributeRewards(signature, rewards);
    }

    function testRevertDistributeRewardsWhenNotAdministratorSignature() public {
        uint256 nonce = jasmyRewards.getSigNonce(user1);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 rewards = 100 ether;

        bytes32 hashedMessage = keccak256(
            abi.encode(
                jasmyRewards.DISTRIBUTE_REWARDS_TYPEHASH(),
                user1,
                rewards,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = jasmyRewards.getDomainSeparator();

        bytes32 digest = _calculateEIP712Digest(domainSeparator, hashedMessage);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PK, digest);

        JasmyRewards.EIP712Signature memory signature = JasmyRewards
            .EIP712Signature({
                signer: user2,
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });

        vm.expectRevert("signature not from administrator");
        vm.prank(user1);
        jasmyRewards.distributeRewards(signature, rewards);
    }

    function testRevertDistributeRewardsWhenCallerNotReceiver() public {
        uint256 nonce = jasmyRewards.getSigNonce(user1);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 rewards = 100 ether;

        bytes32 hashedMessage = keccak256(
            abi.encode(
                jasmyRewards.DISTRIBUTE_REWARDS_TYPEHASH(),
                user1,
                rewards,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = jasmyRewards.getDomainSeparator();

        bytes32 digest = _calculateEIP712Digest(domainSeparator, hashedMessage);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PK, digest);

        JasmyRewards.EIP712Signature memory signature = JasmyRewards
            .EIP712Signature({
                signer: user2,
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });

        vm.expectRevert("signature mismatch");
        vm.prank(user2);
        jasmyRewards.distributeRewards(signature, rewards);
    }

    function testDistributeRewardsExpiredSignature() public {
        uint256 nonce = jasmyRewards.getSigNonce(user1);
        uint256 deadline = block.timestamp; // 已过期
        uint256 rewards = 100 ether;

        vm.warp(10);

        bytes32 hashedMessage = keccak256(
            abi.encode(
                jasmyRewards.DISTRIBUTE_REWARDS_TYPEHASH(),
                user1,
                rewards,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = jasmyRewards.getDomainSeparator();

        bytes32 digest = _calculateEIP712Digest(domainSeparator, hashedMessage);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(administratorPK, digest);

        JasmyRewards.EIP712Signature memory signature = JasmyRewards
            .EIP712Signature({
                signer: administrator,
                v: v,
                r: r,
                s: s,
                deadline: deadline
            });

        vm.expectRevert("signature expired");
        vm.prank(administrator);
        jasmyRewards.distributeRewards(signature, rewards);
    }

    function _calculateEIP712Digest(
        bytes32 domainSeparator,
        bytes32 hashedMessage
    ) internal pure returns (bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, hashedMessage)
        );
        return digest;
    }
}
