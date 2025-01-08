// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTEscrowImpl is UUPSUpgradeable, OwnableUpgradeable {
    event Escrowed(address indexed owner, uint256 indexed tokenId);
    event Unescrowed(address indexed owner, uint256 indexed tokenId);

    address public janctionNFT;

    mapping (uint256 => address) public ownerByToken;

    function initialize(address initialOwner, address nft) public initializer {
        __Ownable_init(initialOwner);
        janctionNFT = nft;
    }

    function withdraw(uint256[] memory tokenIdList, address to) public onlyOwner {
        for(uint256 i = 0; i < tokenIdList.length; ++i) {
            IERC721(janctionNFT).transferFrom(address(this), to, tokenIdList[i]);
        }
    }

    function escrow(uint256 tokenId) public {
        ownerByToken[tokenId] = msg.sender;

        IERC721(janctionNFT).transferFrom(msg.sender, address(this), tokenId);

        emit Escrowed(msg.sender, tokenId);
    }

    function batchEscrow(uint256[] memory tokenIdList) public {
        for(uint256 i = 0; i < tokenIdList.length; ++i) {
            escrow(tokenIdList[i]);
        }
    }

    function unescrow(uint256 tokenId) public {
        require(ownerByToken[tokenId] == msg.sender, "not token id owner");

        delete ownerByToken[tokenId];

        IERC721(janctionNFT).transferFrom(address(this), msg.sender, tokenId);

        emit Unescrowed(msg.sender, tokenId);
    }

    function batchUnescrow(uint256[] memory tokenIdList) public {
        for(uint256 i = 0; i < tokenIdList.length; ++i) {
            unescrow(tokenIdList[i]);
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal onlyOwner virtual override {}
}
