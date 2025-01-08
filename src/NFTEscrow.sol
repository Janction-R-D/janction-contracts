// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTEscrowImpl is ERC721, Ownable {
    uint256 public MAX_SUPPLY;

    uint256 internal _currentTokenId = 1;
    string internal _baseUri;

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        uint256 maxSupply,
        string memory baseUri
    ) ERC721(name, symbol) Ownable(initialOwner) {
        MAX_SUPPLY = maxSupply;
        _baseUri = baseUri;
    }

}
