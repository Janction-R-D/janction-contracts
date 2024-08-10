// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Points} from "../src/Points.sol";

contract PointsTest is Test {
    error OwnableUnauthorizedAccount(address account);

    Points points;
    address owner = address(0x123);
    address user1 = address(0x456);
    address user2 = address(0x789);

    function setUp() public {
        points = new Points(owner);
    }

    function testUpdatePoints() public {
        vm.prank(owner);
        points.updatePoints(user1, 100);

        uint256 user1Points = points.getPointsBy(user1);
        assertEq(user1Points, 100);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        vm.prank(user1);
        points.updatePoints(user2, 200);
    }

    function testBatchUpdatePoints() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        uint256[] memory pointsList = new uint256[](2);
        pointsList[0] = 150;
        pointsList[1] = 250;

        vm.prank(owner);
        points.batchUpdatePoints(accounts, pointsList);

        assertEq(points.getPointsBy(user1), 150);
        assertEq(points.getPointsBy(user2), 250);
    }

    function testBatchUpdatePointsRevertOnArrayLengthMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        uint256[] memory pointsList = new uint256[](1);
        pointsList[0] = 150;

        vm.expectRevert(Points.ArrayLengthMustBeEqual.selector);
        vm.prank(owner);
        points.batchUpdatePoints(accounts, pointsList);
    }

    function testGetPointsBy() public {
        vm.prank(owner);
        points.updatePoints(user1, 200);

        assertEq(points.getPointsBy(user1), 200);

        assertEq(points.getPointsBy(user2), 0);
    }
}
