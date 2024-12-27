// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract JasmyRewards is Ownable, EIP712 {
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

    address public JASMY;

    bytes32 public constant DISTRIBUTE_REWARDS_TYPEHASH =
        keccak256(
            bytes(
                "DistributeRewards(uint256 rewards,uint256 nonce,uint256 deadline)"
            )
        );

    mapping(address => uint256) internal _sigNonces;

    constructor(
        address initialOwner,
        address jasmy
    ) Ownable(initialOwner) EIP712("JasmyRewards", "1") {
        JASMY = jasmy;
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getSigNonce(address user) public view returns (uint256) {
        return _sigNonces[user];
    }

    function setJasmy(address jasmy) public onlyOwner {
        JASMY = jasmy;
    }

    function withdraw(
        address to,
        address currency,
        uint256 amount
    ) public onlyOwner {
        require(to != address(0), "invalid recipient address");
        require(amount > 0, "amount must be greater than zero");

        IERC20(currency).safeTransfer(to, amount);

        emit Withdrawed(to, currency, amount);
    }

    function distributeRewards(
        EIP712Signature memory signature,
        uint256 rewards
    ) public onlyOwner {
        address recoveredAddr = _recoverEIP712Signer(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        DISTRIBUTE_REWARDS_TYPEHASH,
                        rewards,
                        _sigNonces[signature.signer]++,
                        signature.deadline
                    )
                )
            ),
            signature
        );

        require(signature.signer == recoveredAddr, "signature mismatch");

        IERC20(JASMY).safeTransfer(recoveredAddr, rewards);

        emit RewardsDistributed(recoveredAddr, rewards);
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
