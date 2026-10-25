// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

interface ISettlement {
    function settleRound(uint256 roundId, bytes calldata signature) external;
}
