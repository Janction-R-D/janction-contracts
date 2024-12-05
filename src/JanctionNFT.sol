// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract JanctionNFT is ERC721, Ownable {
    event Whitelisted(address indexed to, bool indexed value);

    uint256 internal _tokenIdCount = 1;
    string internal _baseUri;
    mapping(address => bool) public isWhitelisted;

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {}

    modifier onlyWhitelisted {
        require(isWhitelisted[msg.sender], "not whitelisted");
        _;
    }

    function whitelist(address to, bool value) public onlyOwner {
        _whitelist(to, value);
    }

    function setBaseUri(string memory baseUri) public onlyOwner {
        _baseUri = baseUri;
    }

    function mint() public onlyWhitelisted {
        _whitelist(msg.sender, false);
        _mint(msg.sender, _tokenIdCount++);
    }

    function _whitelist(address to, bool value) internal {
        isWhitelisted[to] = value;
        emit Whitelisted(to, value);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
    }
}
