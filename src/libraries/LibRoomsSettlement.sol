// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IEqualFiDrandRegistry } from "../interfaces/IEqualFiDrandRegistry.sol";
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { Round, RoundStatus, Allocations, AssetAccounting } from "../shared/Types.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { LibRoomsMath } from "./LibRoomsMath.sol";
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
    event RoundAllocated(
        uint256 indexed roundId,
        address indexed asset,
        uint256 gross,
        uint256 inherited,
        Allocations allocations
    );

    /// @dev Caller must allocate the returned player pot to one complete outcome in the same call.
    function common(uint256 id, bytes32 seed, uint8 room) internal returns (uint256 playerPot) {
        S.GameStorage storage g = S.gameStorage();
        Round storage r = g.rounds[id];
        if (
            r.status != RoundStatus.SoldOut
                && !(r.status == RoundStatus.Open && block.timestamp >= r.closesAt)
        ) {
            revert Errors.RoundNotReady(id);
        }
        Allocations memory a = LibRoomsMath.allocate(r.receipts, r.config);
        playerPot = r.rolloverIn + a.pot;
        r.status = RoundStatus.Settled;
        r.settledAt = SafeCast.toUint64(block.timestamp);
        r.applicationSeed = seed;
        r.winningRoom = room;
        AssetAccounting storage book = S.accountingStorage().assets[r.config.paymentToken];
        book.activeRoundEscrow -= r.receipts + r.rolloverIn;
        book.pendingOperatorRevenueTotal += a.operatorRevenue;
        S.accountingStorage()
        .pendingOperatorRevenue[r.integrationVersion][r.config.paymentToken] += a.operatorRevenue;
        book.finalizerLiability += a.finalizerTip;
        S.accountingStorage().finalizerCredits[r.config.paymentToken][msg.sender] += a.finalizerTip;
        book.treasuryAvailable += a.treasuryNet;
        delete g.activeRoundForConfig[r.configVersion];
        --g.activeRoundCount;
        emit RoundAllocated(id, r.config.paymentToken, r.receipts, r.rolloverIn, a);
    }
}
