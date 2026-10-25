// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

interface IRooms {
    function openRound(uint64 configVersion, uint8 room, uint256 quantity, uint256 maxPayment)
        external
        returns (uint256 roundId);
    function buyTickets(uint256 roundId, uint8 room, uint256 quantity, uint256 maxPayment) external;
}
