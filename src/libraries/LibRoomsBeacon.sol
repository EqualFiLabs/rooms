// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IEqualFiDrandRegistry } from "../interfaces/IEqualFiDrandRegistry.sol";
import { Errors } from "../shared/Errors.sol";

library LibRoomsBeacon {
    function select(address registry, uint256 boundary) internal view returns (uint64 target) {
        IEqualFiDrandRegistry r = IEqualFiDrandRegistry(registry);
        target = r.firstRoundAfter(boundary);
        if (target == 0 || r.roundTime(target) <= boundary) {
            revert Errors.InvalidRandomnessRound(target);
        }
        if (r.hasSig(target)) revert Errors.StaleRandomnessRound(target);
    }
}
