// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {JanctionNFT} from "../src/JanctionNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract JanctionNFTTest is Test {
    JanctionNFT private nft;
    address private user1;
    address private user2;

    function setUp() public {
        user1 = address(0x456);
        user2 = address(0x789);

        nft = new JanctionNFT("JanctionNFT", "JNFT", address(this), 4800, "");
    }

    function testMint() public {
        // Verify that the contract has no NFTs minted at the start
        uint256 initialTokenCount = nft.totalSupply();
        assertEq(initialTokenCount, 0);

        // Mint a single NFT to user1
        nft.mint(user1);

        // Check if the user1 received the token
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalSupply(), 1);
    }

    function testBatchMint() public {
        // Verify that the contract has no NFTs minted at the start
        uint256 initialTokenCount = nft.totalSupply();
        assertEq(initialTokenCount, 0);

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        // Mint multiple NFTs
        nft.batchMint(users);

        // Verify both users received their tokens
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user2);
        assertEq(nft.totalSupply(), 2);
    }

    function testSetMaxSupply() public {
        string memory newBaseUri = "https://example.com/metadata/";

        // Set a new base URI
        nft.setBaseUri(newBaseUri);

        nft.mint(user1);

        // Check if the base URI has been set correctly
        assertEq(nft.tokenURI(1), string(abi.encodePacked(newBaseUri, "1")));
    }

    function testSetBaseUri() public {
        string memory newBaseUri = "https://example.com/metadata/";

        // Set a new base URI
        nft.setBaseUri(newBaseUri);

        nft.mint(user1);

        // Check if the base URI has been set correctly
        assertEq(nft.tokenURI(1), string(abi.encodePacked(newBaseUri, "1")));
    }

    function testMintWhenExceedsMaxSupply() public {
        nft.setMaxSupply(1);
        nft.mint(user1);

        vm.expectRevert("exceeds max supply");
        nft.mint(user1);
    }

    function testMintByNonOwner() public {
        // Try to mint by a non-owner user and expect revert
        vm.prank(user1); // Simulate user1 calling mint
        vm.expectRevert();
        nft.mint(user1);
    }

    function testBatchMintWhenExceedsMaxSupply() public {
        nft.setMaxSupply(2);
        nft.mint(user1);

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        vm.expectRevert("exceeds max supply");
        nft.batchMint(users);
    }

    function testBatchMintByNonOwner() public {
        // Try to batch mint by a non-owner user and expect revert
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        vm.prank(user1); // Simulate user1 calling batchMint
        vm.expectRevert();
        nft.batchMint(users);
    }
}
