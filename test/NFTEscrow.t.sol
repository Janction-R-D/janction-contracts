// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {JanctionNFT} from "../src/JanctionNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NFTEscrowImpl} from "../src/NFTEscrowImpl.sol";
import {NFTEscrowImplV2} from "./mocks/NFTEscrowImplV2.sol";

contract NFTEscrowTest is Test {
    JanctionNFT nft;
    NFTEscrowImpl nftEscrowImpl;
    NFTEscrowImpl nftEscrowProxy;
    ERC1967Proxy proxy;
    address user1;
    address user2;

    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        nft = new JanctionNFT("JanctionNFT", "JNFT", address(this), 4800, "");

        nft.mint(user1);
        nft.mint(user1);
        nft.mint(user1);
        nft.mint(user2);
        nft.mint(user2);
        nft.mint(user2);

        nftEscrowImpl = new NFTEscrowImpl();
        proxy = new ERC1967Proxy(address(nftEscrowImpl), abi.encodeWithSelector(
            NFTEscrowImpl.initialize.selector,
            address(this),
            address(nft)
        ));
        nftEscrowProxy = NFTEscrowImpl(address(proxy));
    }

    function testInitialize() public view {
        assertEq(nftEscrowProxy.owner(), address(this));
        assertEq(nftEscrowProxy.janctionNFT(), address(nft));
    }

    function testUpgradeToV2() public {
        NFTEscrowImplV2 nftEscrowImplV2 = new NFTEscrowImplV2();

        vm.startPrank(address(this));
        nftEscrowProxy.upgradeToAndCall(address(nftEscrowImplV2), abi.encode(
            NFTEscrowImplV2.initialize2.selector
        ));
        vm.stopPrank();

        NFTEscrowImplV2 nftEscrowProxyV2 = NFTEscrowImplV2(address(nftEscrowProxy));

        assertEq(nftEscrowProxyV2.version(), "2.0");

        vm.startPrank(user1);
        uint256 tokenId = 1;
        nft.approve(address(nftEscrowProxyV2), tokenId);
        nftEscrowProxyV2.escrow(tokenId);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(nftEscrowProxyV2));
        assertEq(nftEscrowProxyV2.ownerByToken(tokenId), user1);
    }

    function testFailUpgradeToV2NotOwner() public {
        NFTEscrowImplV2 nftEscrowImplV2 = new NFTEscrowImplV2();

        vm.startPrank(user1);
        nftEscrowProxy.upgradeToAndCall(address(nftEscrowImplV2), new bytes(0));
        vm.stopPrank();
    }

    function testEscrow() public {
        vm.startPrank(user1);
        uint256 tokenId = 1;
        nft.approve(address(nftEscrowProxy), tokenId);
        nftEscrowProxy.escrow(tokenId);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(nftEscrowProxy));
        assertEq(nftEscrowProxy.ownerByToken(tokenId), user1);
    }

    function testBatchEscrow() public {
        vm.startPrank(user1);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.approve(address(nftEscrowProxy), tokenIds[i]);
        }
        nftEscrowProxy.batchEscrow(tokenIds);
        vm.stopPrank();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(nft.ownerOf(tokenIds[i]), address(nftEscrowProxy));
            assertEq(nftEscrowProxy.ownerByToken(tokenIds[i]), user1);
        }
    }

    function testUnescrow() public {
        vm.startPrank(user1);
        uint256 tokenId = 1;
        nft.approve(address(nftEscrowProxy), tokenId);
        nftEscrowProxy.escrow(tokenId);
        nftEscrowProxy.unescrow(tokenId);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nftEscrowProxy.ownerByToken(tokenId), address(0));
    }

    function testBatchUnescrow() public {
        vm.startPrank(user1);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.approve(address(nftEscrowProxy), tokenIds[i]);
        }
        nftEscrowProxy.batchEscrow(tokenIds);
        nftEscrowProxy.batchUnescrow(tokenIds);
        vm.stopPrank();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(nft.ownerOf(tokenIds[i]), user1);
            assertEq(nftEscrowProxy.ownerByToken(tokenIds[i]), address(0));
        }
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        uint256 tokenId = 1;
        nft.approve(address(nftEscrowProxy), tokenId);
        nftEscrowProxy.escrow(tokenId);
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        nftEscrowProxy.withdraw(tokenIds, user2);

        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(nftEscrowProxy.ownerByToken(tokenId), user1);
    }

    function testFailUnescrowNotOwner() public {
        vm.startPrank(user1);
        uint256 tokenId = 1;
        nft.approve(address(nftEscrowProxy), tokenId);
        nftEscrowProxy.escrow(tokenId);
        vm.stopPrank();

        vm.startPrank(user2);
        nftEscrowProxy.unescrow(tokenId);
        vm.stopPrank();
    }

    function testFailEscrowNotApproved() public {
        vm.startPrank(user1);
        uint256 tokenId = 1;
        nftEscrowProxy.escrow(tokenId);
        vm.stopPrank();
    }

    function testFailWithdrawNotOwner() public {
        vm.startPrank(user1);
        uint256 tokenId = 1;
        nft.approve(address(nftEscrowProxy), tokenId);
        nftEscrowProxy.escrow(tokenId);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        nftEscrowProxy.withdraw(tokenIds, user2);
        vm.stopPrank();
    }
}