// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IRooms } from "../interfaces/IRooms.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibRoomsOpening } from "../libraries/LibRoomsOpening.sol";
import { LibRoomsPurchase } from "../libraries/LibRoomsPurchase.sol";
import { LibRoomsBeacon } from "../libraries/LibRoomsBeacon.sol";
import { Round, RoundStatus } from "../shared/Types.sol";
import { Guarded } from "../shared/Guarded.sol";

contract RoomsFacet is IRooms, Guarded {
    event DeadlineCommitted(uint256 indexed roundId, uint64 deadlineTarget, uint64 effectiveClose);
    event RoundSoldOut(
        uint256 indexed roundId, uint64 deadlineTarget, uint64 selectedTarget, uint64 soldOutAt
    );

    function openRound(uint64 version, uint8 room, uint256 quantity, uint256 maximum)
        external
        nonReentrant
        returns (uint256 id)
    {
        id = LibRoomsOpening.reserve(version);
        Round storage r = S.gameStorage().rounds[id];
        uint64 target =
            LibRoomsBeacon.select(_registry(r), uint256(r.closesAt) + r.config.randomnessDelay);
        r.deadlineDrandRound = target;
        r.drandRound = target;
        emit DeadlineCommitted(id, target, r.effectiveClose);
        _purchase(id, room, quantity, maximum);
    }

    function buyTickets(uint256 id, uint8 room, uint256 quantity, uint256 maximum)
        external
        nonReentrant
    {
        _purchase(id, room, quantity, maximum);
    }

    function _purchase(uint256 id, uint8 room, uint256 quantity, uint256 maximum) private {
        uint256 payment = LibRoomsPurchase.record(id, room, quantity, maximum);
        Round storage r = S.gameStorage().rounds[id];
        if (r.totalTickets == r.config.ticketSupply) {
            uint64 at = SafeCast.toUint64(block.timestamp);
            uint64 target =
                LibRoomsBeacon.select(_registry(r), uint256(at) + r.config.randomnessDelay);
            r.soldOutAt = at;
            r.effectiveClose = at;
            r.drandRound = target;
            r.status = RoundStatus.SoldOut;
            emit RoundSoldOut(id, r.deadlineDrandRound, target, at);
        }
        LibRoomsPurchase.collect(id, payment);
    }

    function _registry(Round storage r) private view returns (address) {
        return S.integrationStorage().integrations[r.integrationVersion].drandRegistry;
    }
}
