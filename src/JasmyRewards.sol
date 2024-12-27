// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract JasmyRewards is Ownable {
    using SafeERC20 for IERC20;

    error ArrayLengthMustBeEqual();

    event Withdrawed(address indexed to, address indexed currency, uint256 amount);
    event RewardsUpdated(address indexed account, uint256 rewards);
    event RewardsClaimed(address indexed account, uint256 rewards);

    address public JASMY;

    mapping(address => uint256) internal _rewards;

    constructor(address initialOwner, address jasmy) Ownable(initialOwner) {
        JASMY = jasmy;
    }

    function setJasmy(address jasmy) public onlyOwner {
        JASMY = jasmy;
    }

    function withdraw(address to, address currency, uint256 amount) public onlyOwner {
        IERC20(currency).safeTransfer(to, amount);
        emit Withdrawed(to, currency, amount);
    }

    function claim() public {
        uint256 value =  _rewards[msg.sender];
        
        require(IERC20(JASMY).balanceOf(address(this)) >= value, "Insufficient JASMY balance");

        _rewards[msg.sender] = 0;

        IERC20(JASMY).safeTransfer(msg.sender, value);

        emit RewardsClaimed(msg.sender, value);
    }

    function updateRewards(address account, uint256 rewards) public onlyOwner {
        _rewards[account] = rewards;
        emit RewardsUpdated(account, rewards);
    }

    function batchUpdateRewards(
        address[] calldata accountList,
        uint256[] calldata rewardsList
    ) public onlyOwner {
        if (accountList.length != rewardsList.length) {
            revert ArrayLengthMustBeEqual();
        }
        for (uint256 i = 0; i < accountList.length; ++i) {
            _rewards[accountList[i]] = rewardsList[i];
            emit RewardsUpdated(accountList[i], rewardsList[i]);
        }
    }

    function getRewardsBy(address account) public view returns (uint256) {
        return _rewards[account];
    }
}
