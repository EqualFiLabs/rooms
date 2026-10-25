// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IEqualFiDrandRegistry } from "../interfaces/IEqualFiDrandRegistry.sol";
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { Round, RoundStatus } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";

/// @dev Internal components only; the public transition is installed with both outcome branches.
library LibRoomsSettlement {
    function acquire(uint256 id, bytes calldata signature)
        internal
        returns (bytes32 seed, uint8 room)
    {
        Round storage r = S.gameStorage().rounds[id];
        if (r.status == RoundStatus.None) revert Errors.RoundNotFound(id);
        if (
            r.status != RoundStatus.SoldOut
                && !(r.status == RoundStatus.Open && block.timestamp >= r.closesAt)
        ) {
            revert Errors.RoundNotReady(id);
        }
        IEqualFiDrandRegistry registry = IEqualFiDrandRegistry(
            S.integrationStorage().integrations[r.integrationVersion].drandRegistry
        );
        uint64 target = r.drandRound;
        if (!registry.hasSig(target)) registry.postSig(target, signature);
        if (!registry.hasSig(target)) revert Errors.RandomnessUnavailable(target);
        uint64 posted = registry.postedAt(target);
        if (posted <= r.effectiveClose) {
            revert Errors.RandomnessPredatesClose(target, posted, r.effectiveClose);
        }
        seed = keccak256(
            abi.encode(registry.randomnessOf(target), block.chainid, address(this), id)
        );
        room = uint8(uint256(seed) % r.config.roomCount);
    }
}
