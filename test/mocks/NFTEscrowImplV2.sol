// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {NFTEscrowImpl} from "../../src/NFTEscrowImpl.sol";

contract NFTEscrowImplV2 is NFTEscrowImpl {
    string public version;
    function initialize2() public reinitializer(2) {
        version = "2.0";
    }
}