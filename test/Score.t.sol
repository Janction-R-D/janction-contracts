// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/Score.sol";

contract ScoreTest is Test {
    error OwnableUnauthorizedAccount(address account);
    error ArrayLengthMustBeEqual();

    Score score;
    address owner = makeAddr("owner");
    address addr1 = makeAddr("addr1");
    address addr2 = makeAddr("addr2");

    function setUp() public {
        score = new Score(owner);
    }

    function testIncrementScore() public {
        vm.prank(owner);
        score.incrementScore(addr1, 10);
        assertEq(score.getScore(addr1), 10);

        vm.prank(owner);
        score.incrementScore(addr1, 5);
        assertEq(score.getScore(addr1), 15);
    }

    function testBatchIncrementScore() public {
        address[] memory accounts = new address[](2);
        uint256[] memory scores = new uint256[](2);

        accounts[0] = addr1;
        accounts[1] = addr2;
        scores[0] = 10;
        scores[1] = 20;

        vm.prank(owner);
        score.batchIncrementScore(accounts, scores);

        assertEq(score.getScore(addr1), 10);
        assertEq(score.getScore(addr2), 20);
    }

    function testOnlyOwnerCanIncrementScore() public {
        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, addr1));
        score.incrementScore(addr1, 10);
    }

    function testOnlyOwnerCanBatchIncrementScore() public {
        address[] memory accounts = new address[](2);
        uint256[] memory scores = new uint256[](2);

        accounts[0] = addr1;
        accounts[1] = addr2;
        scores[0] = 10;
        scores[1] = 20;

        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, addr1));
        score.batchIncrementScore(accounts, scores);
    }

    function testArrayLengthMismatch() public {
        address[] memory accounts = new address[](1);
        uint256[] memory scores = new uint256[](2);

        accounts[0] = addr1;
        scores[0] = 10;
        scores[1] = 20;

        vm.prank(owner);
        vm.expectRevert(ArrayLengthMustBeEqual.selector);
        score.batchIncrementScore(accounts, scores);
    }

    function testBatchIncrementScoreWithLargeArray() public {
        uint256 maxArraySize = 1000; // Adjust this based on the first test result: 24715767

        address[] memory accounts = new address[](maxArraySize);
        uint256[] memory increments = new uint256[](maxArraySize);

        for (uint256 i = 0; i < maxArraySize; i++) {
            accounts[i] = address(uint160(i));
            increments[i] = 100;
        }

        vm.startPrank(owner);
        uint256 gasBefore = gasleft();
        score.batchIncrementScore(accounts, increments);
        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        emit log_named_uint("Gas used for large array", gasUsed);

        vm.stopPrank();
    }
}
