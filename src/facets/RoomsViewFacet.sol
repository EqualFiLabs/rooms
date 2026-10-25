// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IRoomsView } from "../interfaces/IRoomsView.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibRoomsMath as M } from "../libraries/LibRoomsMath.sol";
import { LibRoomsAccounting as A } from "../libraries/LibRoomsAccounting.sol";
import {
    RoomsConfig,
    IntegrationConfig,
    Round,
    RoundStatus,
    RoundPhase,
    AssetAccounting
} from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";

contract RoomsViewFacet is IRoomsView {
    function roomsConfig(uint64 v) external view returns (RoomsConfig memory, bool) {
        return (S.gameStorage().configs[v], S.gameStorage().configEnabled[v]);
    }

    function integrationVersion(uint64 v) external view returns (IntegrationConfig memory) {
        return S.integrationStorage().integrations[v];
    }

    function round(uint256 id) external view returns (Round memory) {
        return S.gameStorage().rounds[id];
    }

    function roundPhase(uint256 id) external view returns (RoundPhase) {
        Round storage r = S.gameStorage().rounds[id];
        if (r.status == RoundStatus.None) return RoundPhase.None;
        if (r.status == RoundStatus.Settled) return RoundPhase.Settled;
        if (r.status == RoundStatus.SoldOut) return RoundPhase.SoldOut;
        return block.timestamp >= r.closesAt ? RoundPhase.Locked : RoundPhase.Open;
    }

    function roomTicketCount(uint256 id, uint8 room) external view returns (uint256) {
        return S.gameStorage().roomTickets[id][room];
    }

    function roomTicketCounts(uint256 id) external view returns (uint256[] memory counts) {
        S.GameStorage storage g = S.gameStorage();
        counts = new uint256[](g.rounds[id].config.roomCount);
        for (uint8 room; room < counts.length; ++room) {
            counts[room] = g.roomTickets[id][room];
        }
    }

    function userRoomTicketCount(uint256 id, uint8 room, address user)
        external
        view
        returns (uint256)
    {
        return S.gameStorage().userRoomTickets[id][room][user];
    }

    function prizeClaimed(uint256 id, address user) external view returns (bool) {
        return S.gameStorage().prizeClaimed[id][user];
    }

    function claimablePrize(uint256 id, address user) external view returns (uint256) {
        S.GameStorage storage g = S.gameStorage();
        Round storage r = g.rounds[id];
        if (
            r.status != RoundStatus.Settled || r.prizeExpired || block.timestamp >= r.claimDeadline
                || g.prizeClaimed[id][user]
        ) return 0;
        return g.userRoomTickets[id][r.winningRoom][user] * r.payoutPerTicket;
    }

    function finalizerCredit(address asset, address user) external view returns (uint256) {
        return S.accountingStorage().finalizerCredits[asset][user];
    }

    function pendingOperatorRevenue(uint64 v, address asset) external view returns (uint256) {
        return S.accountingStorage().pendingOperatorRevenue[v][asset];
    }

    function assetAccounting(address asset) external view returns (AssetAccounting memory) {
        return S.accountingStorage().assets[asset];
    }

    function assetBalanceAndAccounted(address asset) external view returns (uint256, uint256) {
        return A.balanceAndAccounted(asset);
    }

    function isAssetApproved(address asset) external view returns (bool) {
        return S.accountingStorage().assetApproved[asset];
    }

    function isKnownAsset(address asset) external view returns (bool) {
        return S.accountingStorage().knownAsset[asset];
    }

    function pendingRollover(uint64 v) external view returns (uint256) {
        return S.gameStorage().pendingRollover[v];
    }

    function activeRoundForConfig(uint64 v) external view returns (uint256) {
        return S.gameStorage().activeRoundForConfig[v];
    }

    function maxActiveRounds() external view returns (uint16) {
        return S.gameStorage().maxActiveRounds;
    }

    function activeRoundCount() external view returns (uint256) {
        return S.gameStorage().activeRoundCount;
    }

    function quotePurchase(uint256 id, uint256 quantity)
        public
        view
        returns (uint8 e, uint16 multiplierBps, uint256 unit, uint256 payment, uint256 remaining)
    {
        Round storage r = S.gameStorage().rounds[id];
        if (r.status == RoundStatus.None) revert Errors.RoundNotFound(id);
        if (r.status != RoundStatus.Open || block.timestamp >= r.closesAt) {
            revert Errors.RoundNotOpen(id);
        }
        if (quantity == 0) revert Errors.InvalidTicketQuantity();
        if (r.config.maxTicketsPerPurchase != 0 && quantity > r.config.maxTicketsPerPurchase) {
            revert Errors.TicketLimitExceeded();
        }
        remaining = r.config.ticketSupply - r.totalTickets;
        if (quantity > remaining) revert Errors.InsufficientSupply(quantity, remaining);
        e = M.epoch(block.timestamp - r.openedAt, r.config.salesDuration);
        multiplierBps = M.multiplier(e);
        unit = M.unitPrice(r.config.baseTicketPrice, e);
        payment = unit * quantity;
    }

    function previewRoomPayout(uint256 id, uint8 room, uint256 additionalTickets)
        external
        view
        returns (uint256 pot, uint256 tickets, uint256 unit)
    {
        Round storage r = S.gameStorage().rounds[id];
        if (r.status == RoundStatus.None) revert Errors.RoundNotFound(id);
        if (r.status == RoundStatus.Settled) revert Errors.RoundNotOpen(id);
        if (room >= r.config.roomCount) revert Errors.InvalidRoom(room);
        uint256 payment;
        if (additionalTickets != 0) (,,, payment,) = quotePurchase(id, additionalTickets);
        pot = r.rolloverIn + M.allocate(r.receipts + payment, r.config).pot;
        tickets = S.gameStorage().roomTickets[id][room] + additionalTickets;
        (unit,,) = M.perTicket(pot, tickets);
    }
}
