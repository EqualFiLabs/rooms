// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ISettlement } from "../interfaces/ISettlement.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibRoomsSettlement } from "../libraries/LibRoomsSettlement.sol";
import { LibRoomsOutcome } from "../libraries/LibRoomsOutcome.sol";
import { Round } from "../shared/Types.sol";
import { Guarded } from "../shared/Guarded.sol";

contract SettlementFacet is ISettlement, Guarded {
    event RoundSettled(
        uint256 indexed roundId,
        uint8 indexed winningRoom,
        address indexed finalizer,
        bytes32 seed,
        uint256 winningTickets,
        uint256 playerPot,
        uint256 payoutPerTicket,
        uint256 distributable,
        uint64 claimDeadline
    );

    function settleRound(uint256 id, bytes calldata signature)
        external
        nonReentrant
        returns (uint8 winningRoom)
    {
        bytes32 seed;
        (seed, winningRoom) = LibRoomsSettlement.acquire(id, signature);
        uint256 playerPot = LibRoomsSettlement.common(id, seed, winningRoom);
        uint256 winners = S.gameStorage().roomTickets[id][winningRoom];
        if (winners == 0) LibRoomsOutcome.rollover(id, playerPot);
        else LibRoomsOutcome.populated(id, playerPot, winners);
        Round storage r = S.gameStorage().rounds[id];
        emit RoundSettled(
            id,
            winningRoom,
            msg.sender,
            seed,
            winners,
            playerPot,
            r.payoutPerTicket,
            r.prizeRemaining,
            r.claimDeadline
        );
    }
}
