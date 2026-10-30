// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ClaimsTest } from "./helpers/ClaimsTest.sol";
import { RoomsConfig, Round, AssetAccounting } from "./helpers/RoomsTest.sol";
import { RoundStatus } from "../src/shared/Types.sol";

contract RoomsSettlementIntegrationTest is ClaimsTest {
    mapping(uint256 => uint256) internal prizePaid;
    mapping(uint256 => uint256) internal expired;
    uint256 internal finalizerPaid;

    function reconcile(uint256 lastRound, uint64 lastConfig) internal view {
        uint256 escrow;
        uint256 prizes;
        uint256 rollover;
        uint256 tips;
        uint256 operators;
        uint256 treasuryTotal;
        for (uint256 id = 1; id <= lastRound; ++id) {
            Round memory r = inspect.roundState(id);
            if (r.status == RoundStatus.Open || r.status == RoundStatus.SoldOut) {
                escrow += r.receipts + r.rolloverIn;
            }
            if (r.status != RoundStatus.Settled) continue;
            // Independent reference arithmetic is bounded by these funded test fixtures.
            uint256 pot = r.receipts * r.config.potBps / 10_000;
            uint256 op = r.receipts * r.config.operatorBps / 10_000;
            uint256 tg = r.receipts - pot - op;
            uint256 tip = tg * r.config.settlementTipBps / 10_000;
            operators += op;
            tips += tip;
            treasuryTotal += tg - tip + expired[id];
            (uint256 winning,) = inspect.tickets(id, r.winningRoom, address(0));
            if (winning != 0) {
                uint256 initial = (r.rolloverIn + pot) / winning * winning;
                uint256 remaining = initial - prizePaid[id] - expired[id];
                assertEq(r.prizeRemaining, remaining);
                prizes += remaining;
            }
        }
        rollover = referenceRollover(lastRound, lastConfig);
        AssetAccounting memory a = inspect.accounting(address(token));
        assertEq(a.activeRoundEscrow, escrow);
        assertEq(a.prizeLiability, prizes);
        assertEq(a.pendingRolloverTotal, rollover);
        assertEq(a.finalizerLiability, tips - finalizerPaid);
        assertEq(a.pendingOperatorRevenueTotal, operators);
        assertEq(a.treasuryAvailable, treasuryTotal);
        assertEq(inspect.bucket(1, address(token)), operators);
        assertEq(inspect.credit(address(token), address(this)), tips - finalizerPaid);
        assertBacked(address(token));
    }

    function referenceRollover(uint256 lastRound, uint64 lastConfig)
        internal
        view
        returns (uint256 total)
    {
        uint256[] memory pots = new uint256[](uint256(lastConfig) + 1);
        for (uint256 id = 1; id <= lastRound; ++id) {
            Round memory r = inspect.roundState(id);
            assertEq(r.rolloverIn, pots[r.configVersion]);
            pots[r.configVersion] = 0;
            if (r.status != RoundStatus.Settled) continue;
            uint256 pot = r.rolloverIn + r.receipts * r.config.potBps / 10_000;
            (uint256 winners,) = inspect.tickets(id, r.winningRoom, address(0));
            pots[r.configVersion] = winners == 0 ? pot : pot % winners;
        }
        for (uint64 v = 1; v <= lastConfig; ++v) {
            assertEq(inspect.rollover(v), pots[v]);
            total += pots[v];
        }
    }

    function testRepeatedEmptyThenPopulatedPartialClaimAndExpiryReconcileEverySource() public {
        for (uint256 i; i < 2; ++i) {
            uint256 emptyId = open(1, 0, 10);
            reconcile(emptyId, 1);
            finish(emptyId, 1);
            reconcile(emptyId, 1);
        }
        uint256 id = open(1, 0, 3);
        buy(id, bob, 0, 2);
        buy(id, alice, 1, 5);
        reconcile(id, 1);
        finish(id, 0);
        assertEq(inspect.roundState(id).rolloverIn, 10 ether);
        assertEq(inspect.roundState(id).payoutPerTicket, 3 ether);
        reconcile(id, 1);
        vm.prank(alice);
        prizePaid[id] = claims.claimPrize(id, alice);
        assertEq(prizePaid[id], 9 ether);
        reconcile(id, 1);
        vm.warp(inspect.roundState(id).claimDeadline); // Lazy expiry remains an obligation.
        reconcile(id, 1);
        expired[id] = claims.expirePrize(id);
        assertEq(expired[id], 6 ether);
        reconcile(id, 1);
        finalizerPaid = claims.claimFinalizerTips(address(token), bob);
        reconcile(id, 1);
        uint256 next = open(1, 0, 1);
        reconcile(next, 1);
        assertEq(inspect.roundState(next).rolloverIn, 0);
    }

    function testConcurrentConfigurationsSettleInReverseOrderWithoutSharingPots() public {
        uint64 v = gov.createRoomsConfig(fixture());
        gov.setRoomsConfigEnabled(v, true);
        uint256 first = open(1, 0, 2);
        vm.warp(block.timestamp + 3);
        uint256 second = open(v, 1, 4);
        vm.warp(block.timestamp + 100);
        buy(first, bob, 1, 2);
        buy(second, bob, 1, 2);
        reconcile(second, v);
        finish(second, 0);
        reconcile(second, v);
        assertGt(inspect.rollover(v), 0);
        finish(first, 1);
        reconcile(second, v);
        assertEq(inspect.rollover(1), 0);
        vm.prank(bob);
        prizePaid[first] = claims.claimPrize(first, bob);
        reconcile(second, v);
        uint256 successor = open(v, 1, 1);
        assertGt(inspect.roundState(successor).rolloverIn, 0);
        reconcile(successor, v);
    }

    function testCompleteLifecycleContinuesAfterCodeFinalization() public {
        gov.finalizeProtocol();
        assertTrue(gov.protocolFinalized());
        uint256 id = open(1, 0, 30);
        buy(id, bob, 0, 20);
        buy(id, alice, 1, 50);
        finish(id, 0);
        reconcile(id, 1);
        vm.prank(alice);
        prizePaid[id] = claims.claimPrize(id, alice);
        vm.prank(bob);
        prizePaid[id] += claims.claimPrize(id, bob);
        reconcile(id, 1);
        gov.setMaxActiveRounds(2);
        uint64 v = gov.createRoomsConfig(fixture());
        gov.setRoomsConfigEnabled(v, true);
        uint256 next = open(v, 1, 1);
        reconcile(next, v);
    }
}
