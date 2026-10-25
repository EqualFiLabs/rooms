// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { Round } from "../shared/Types.sol";

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
}
