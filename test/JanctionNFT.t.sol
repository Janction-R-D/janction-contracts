// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/JanctionNFT.sol";

contract JanctionNFTTest is Test {
    JanctionNFT public nft;
    address public owner = address(1);
    address public whitelisted = address(2);
    address public notWhitelisted = address(3);

    function setUp() public {
        vm.startPrank(owner);
        nft = new JanctionNFT("TestNFT", "TNFT", owner);
        vm.stopPrank();
    }

    function testWhitelist() public {
        vm.startPrank(notWhitelisted);
        vm.expectRevert("not whitelisted");
        nft.mint(1);
        vm.stopPrank();

        vm.startPrank(owner);
        nft.whitelist(whitelisted, true);
        assertEq(nft.isWhitelisted(whitelisted), true); 
        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(owner);
        nft.whitelist(whitelisted, true);
        vm.stopPrank();

        vm.startPrank(whitelisted);
        nft.mint(1);
        assertEq(nft.ownerOf(1), whitelisted); 
        vm.stopPrank();
    }

    function testSetBaseUri() public {
        string memory baseUri = "https://api.example.com/metadata/";
        vm.startPrank(owner);
        nft.setBaseUri(baseUri);
        vm.stopPrank();

        vm.startPrank(owner);
        nft.whitelist(whitelisted, true);
        vm.startPrank(whitelisted);
        nft.mint(100);

        assertEq(nft.tokenURI(100), "https://api.example.com/metadata/100"); 
    }

    function testOnlyOwnerFunctions() public {
        vm.startPrank(notWhitelisted);
        vm.expectRevert();
        nft.setBaseUri("https://api.example.com/metadata/");
        vm.stopPrank();
    }
}
