// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IClaims } from "../interfaces/IClaims.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { Round, RoundStatus } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";
import { Guarded } from "../shared/Guarded.sol";

contract ClaimsFacet is IClaims, Guarded {
    using SafeERC20 for IERC20;
    event PrizeClaimed(
        uint256 indexed roundId,
        address indexed player,
        address indexed receiver,
        uint256 tickets,
        uint256 amount
    );

    function claimPrize(uint256 id, address receiver)
        external
        nonReentrant
        returns (uint256 amount)
    {
        _receiver(receiver);
        Round storage r = _settledPopulated(id);
        if (block.timestamp >= r.claimDeadline) revert Errors.PrizeExpired();
        S.GameStorage storage g = S.gameStorage();
        if (g.prizeClaimed[id][msg.sender]) revert Errors.PrizeAlreadyClaimed();
        uint256 tickets = g.userRoomTickets[id][r.winningRoom][msg.sender];
        amount = tickets * r.payoutPerTicket;
        if (amount == 0) revert Errors.NoPrize();
        g.prizeClaimed[id][msg.sender] = true;
        r.prizeRemaining -= amount;
        S.accountingStorage().assets[r.config.paymentToken].prizeLiability -= amount;
        emit PrizeClaimed(id, msg.sender, receiver, tickets, amount);
        IERC20(r.config.paymentToken).safeTransfer(receiver, amount);
    }

    event PrizeExpired(uint256 indexed roundId, address indexed asset, uint256 amount);

    function expirePrize(uint256 id) external nonReentrant returns (uint256 amount) {
        Round storage r = _settledPopulated(id);
        if (block.timestamp < r.claimDeadline) revert Errors.PrizeNotExpired();
        if (r.prizeExpired) revert Errors.PrizeAlreadyExpired();
        r.prizeExpired = true;
        amount = r.prizeRemaining;
        r.prizeRemaining = 0;
        S.accountingStorage().assets[r.config.paymentToken].prizeLiability -= amount;
        S.accountingStorage().assets[r.config.paymentToken].treasuryAvailable += amount;
        emit PrizeExpired(id, r.config.paymentToken, amount);
    }

    event FinalizerTipsClaimed(
        address indexed asset, address indexed finalizer, address indexed receiver, uint256 amount
    );

    function claimFinalizerTips(address asset, address receiver)
        external
        nonReentrant
        returns (uint256 amount)
    {
        _receiver(receiver);
        S.AccountingStorage storage a = S.accountingStorage();
        amount = a.finalizerCredits[asset][msg.sender];
        if (amount == 0) revert Errors.NoFinalizerCredit();
        a.finalizerCredits[asset][msg.sender] = 0;
        a.assets[asset].finalizerLiability -= amount;
        emit FinalizerTipsClaimed(asset, msg.sender, receiver, amount);
        IERC20(asset).safeTransfer(receiver, amount);
    }

    function _receiver(address receiver) private view {
        if (receiver == address(0) || receiver == address(this)) revert Errors.InvalidAddress();
    }

    function _settledPopulated(uint256 id) private view returns (Round storage r) {
        r = S.gameStorage().rounds[id];
        if (r.status == RoundStatus.None) revert Errors.RoundNotFound(id);
        if (r.status != RoundStatus.Settled) revert Errors.RoundNotSettled(id);
        if (S.gameStorage().roomTickets[id][r.winningRoom] == 0) revert Errors.EmptyWinningRoom();
    }
}
