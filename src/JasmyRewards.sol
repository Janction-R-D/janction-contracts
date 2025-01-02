// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract JasmyRewards is Ownable, EIP712, Pausable {
    using SafeERC20 for IERC20;

    struct EIP712Signature {
        address signer;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    event Withdrawed(
        address indexed to,
        address indexed currency,
        uint256 amount
    );
    event RewardsDistributed(address indexed account, uint256 rewards);

    bytes32 public constant DISTRIBUTE_REWARDS_TYPEHASH =
        keccak256(
            bytes(
                "DistributeRewards(address receiver,uint256 rewards,uint256 nonce,uint256 deadline)"
            )
        );

    address internal _administrator;

    address public JASMY;

    uint256 public MAX_DISTRIBUTE_AMOUNT;

    mapping(address => uint256) internal _sigNonces;

    constructor(
        address initialOwner,
        address administrator,
        address jasmy,
        uint256 maxDistributeAmount
    ) Ownable(initialOwner) EIP712("JasmyRewards", "1") {
        _administrator = administrator;
        JASMY = jasmy;
        MAX_DISTRIBUTE_AMOUNT = maxDistributeAmount;
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getSigNonce(address user) public view returns (uint256) {
        return _sigNonces[user];
    }

    function setAdministrator(address administrator) public onlyOwner {
        _administrator = administrator;
    }

    function setJasmy(address jasmy) public onlyOwner {
        JASMY = jasmy;
    }

    function setMaxDistributeAmount(uint256 maxDistributeAmount) public onlyOwner {
        MAX_DISTRIBUTE_AMOUNT = maxDistributeAmount;
    }

    function withdraw(
        address to,
        uint256 amount
    ) public onlyOwner {
        require(to != address(0), "invalid recipient address");
        require(amount > 0, "amount must be greater than zero");

        IERC20(JASMY).safeTransfer(to, amount);

        emit Withdrawed(to, JASMY, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function distributeRewards(
        EIP712Signature memory signature,
        uint256 rewards
    ) public whenNotPaused {
        address receiver = msg.sender;

        address recoveredAddr = _recoverEIP712Signer(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        DISTRIBUTE_REWARDS_TYPEHASH,
                        receiver,
                        rewards,
                        _sigNonces[receiver]++,
                        signature.deadline
                    )
                )
            ),
            signature
        );

        require(signature.signer == recoveredAddr, "signature mismatch");

        require(signature.signer == _administrator, "signature not from administrator");

        require(rewards <= MAX_DISTRIBUTE_AMOUNT, "distribute amount too large");

        IERC20(JASMY).safeTransfer(receiver, rewards);

        emit RewardsDistributed(receiver, rewards);
    }

    function _recoverEIP712Signer(
        bytes32 digest,
        EIP712Signature memory signature
    ) internal view returns (address) {
        require(block.timestamp < signature.deadline, "signature expired");
        address recoveredAddress = ecrecover(
            digest,
            signature.v,
            signature.r,
            signature.s
        );
        return recoveredAddress;
    }
}
