// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { LibRoomsMath as M } from "./LibRoomsMath.sol";
import { Round, RoundStatus } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";

library LibRoomsPurchase {
    using SafeERC20 for IERC20;
    event TicketsPurchased(
        uint256 indexed roundId,
        address indexed buyer,
        uint8 indexed room,
        uint256 quantity,
        uint8 epoch,
        uint256 unitPrice,
        uint256 payment,
        uint256 ticketsRemaining
    );

    /// @dev Internal purchase component. The complete public caller also commits exact-fill sellout.
    function record(uint256 id, uint8 room, uint256 quantity, uint256 maximum) internal {
        S.GameStorage storage g = S.gameStorage();
        Round storage r = g.rounds[id];
        if (r.status == RoundStatus.None) revert Errors.RoundNotFound(id);
        if (S.governanceStorage().paused) revert Errors.ProtocolPaused();
        if (r.status != RoundStatus.Open || block.timestamp >= r.closesAt) {
            revert Errors.RoundNotOpen(id);
        }
        if (!S.accountingStorage().assetApproved[r.config.paymentToken]) {
            revert Errors.AssetNotApproved(r.config.paymentToken);
        }
        if (room >= r.config.roomCount) revert Errors.InvalidRoom(room);
        if (quantity == 0) revert Errors.InvalidTicketQuantity();
        if (r.config.maxTicketsPerPurchase != 0 && quantity > r.config.maxTicketsPerPurchase) {
            revert Errors.TicketLimitExceeded();
        }
        uint256 remaining = r.config.ticketSupply - r.totalTickets;
        if (quantity > remaining) revert Errors.InsufficientSupply(quantity, remaining);
        uint8 e = M.epoch(block.timestamp - r.openedAt, r.config.salesDuration);
        uint256 unit = M.unitPrice(r.config.baseTicketPrice, e);
        uint256 payment = unit * quantity;
        if (payment > maximum) revert Errors.MaximumPaymentExceeded(payment, maximum);
        r.totalTickets += quantity;
        r.receipts += payment;
        g.roomTickets[id][room] += quantity;
        g.userRoomTickets[id][room][msg.sender] += quantity;
        S.accountingStorage().assets[r.config.paymentToken].activeRoundEscrow += payment;
        emit TicketsPurchased(
            id, msg.sender, room, quantity, e, unit, payment, remaining - quantity
        );
        IERC20(r.config.paymentToken).safeTransferFrom(msg.sender, address(this), payment);
    }
}
