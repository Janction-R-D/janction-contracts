// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/JanctionNFT.sol";

contract JanctionNFTTest is Test {
    JanctionNFT public nft;
    address public owner = address(1);
    address public whitelisted1 = address(2);
    address public whitelisted2 = address(3);
    address public notWhitelisted = address(4);

    function setUp() public {
        vm.startPrank(owner);
        nft = new JanctionNFT("TestNFT", "TNFT", owner);
        vm.stopPrank();
    }

    function testWhitelist() public {
        vm.startPrank(notWhitelisted);
        vm.expectRevert("not whitelisted");
        nft.mint();
        vm.stopPrank();

        vm.startPrank(owner);
        nft.whitelist(whitelisted1, true);
        assertEq(nft.isWhitelisted(whitelisted1), true); 
        nft.whitelist(whitelisted2, true);
        assertEq(nft.isWhitelisted(whitelisted2), true); 
        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(owner);
        nft.whitelist(whitelisted1, true);
        nft.whitelist(whitelisted2, true);
        vm.stopPrank();

        vm.startPrank(whitelisted1);
        nft.mint();
        assertEq(nft.ownerOf(1), whitelisted1); 
        vm.stopPrank();

        vm.startPrank(whitelisted2);
        nft.mint();
        assertEq(nft.ownerOf(2), whitelisted2); 
        vm.stopPrank();
    }

    function testRevertWhenDoubleMint() public {
        vm.startPrank(owner);
        nft.whitelist(whitelisted1, true);
        vm.stopPrank();

        vm.startPrank(whitelisted1);
        nft.mint();
        assertEq(nft.ownerOf(1), whitelisted1); 
        vm.stopPrank();

        vm.startPrank(whitelisted1);
        vm.expectRevert("not whitelisted");
        nft.mint();
        vm.stopPrank();
    }

    function testSetBaseUri() public {
        string memory baseUri = "https://api.example.com/metadata/";
        vm.startPrank(owner);
        nft.setBaseUri(baseUri);
        vm.stopPrank();

        vm.startPrank(owner);
        nft.whitelist(whitelisted1, true);
        vm.startPrank(whitelisted1);
        nft.mint();

        assertEq(nft.tokenURI(1), "https://api.example.com/metadata/1"); 
    }

    function testOnlyOwnerFunctions() public {
        vm.startPrank(notWhitelisted);
        vm.expectRevert();
        nft.setBaseUri("https://api.example.com/metadata/");
        vm.stopPrank();
    }
}
