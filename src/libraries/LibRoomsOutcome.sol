// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { Round } from "../shared/Types.sol";

import { LibRoomsMath } from "./LibRoomsMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library LibRoomsOutcome {
    event RolloverCredited(
        uint256 indexed roundId, uint64 indexed configVersion, address indexed asset, uint256 amount
    );

    function rollover(uint256 id, uint256 amount) internal {
        Round storage r = S.gameStorage().rounds[id];
        S.gameStorage().pendingRollover[r.configVersion] += amount;
        S.accountingStorage().assets[r.config.paymentToken].pendingRolloverTotal += amount;
        emit RolloverCredited(id, r.configVersion, r.config.paymentToken, amount);
    }

    function populated(uint256 id, uint256 pot, uint256 winningTickets) internal {
        Round storage r = S.gameStorage().rounds[id];
        (uint256 unit, uint256 distributable, uint256 dust) =
            LibRoomsMath.perTicket(pot, winningTickets);
        r.payoutPerTicket = unit;
        r.prizeRemaining = distributable;
        r.claimDeadline = SafeCast.toUint64(uint256(r.settledAt) + 30 days);
        S.accountingStorage().assets[r.config.paymentToken].prizeLiability += distributable;
        rollover(id, dust);
    }
}
