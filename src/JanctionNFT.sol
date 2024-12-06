// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract JanctionNFT is ERC721, Ownable {
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

    function setMaxSupply(uint256 maxSupply) public onlyOwner {
        require(maxSupply > totalSupply(), "invalid max supply");
        MAX_SUPPLY = maxSupply;
    }

    function setBaseUri(string memory baseUri) public onlyOwner {
        _baseUri = baseUri;
    }

    function mint(address to) public onlyOwner {
        require(_currentTokenId <= MAX_SUPPLY, "exceeds max supply");
        _mint(to, _currentTokenId++);
    }

    function batchMint(address[] memory tos) public onlyOwner {
        require(_currentTokenId + tos.length -1 <= MAX_SUPPLY, "exceeds max supply");
        for(uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], _currentTokenId++);
        }
    }

    function totalSupply() public view returns (uint256) {
        return _currentTokenId - 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
    }
}
