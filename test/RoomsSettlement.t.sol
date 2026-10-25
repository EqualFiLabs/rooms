// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { SettlementTest } from "./helpers/SettlementTest.sol";
import {
    RoomsConfig,
    Round,
    Errors,
    IntegrationConfig,
    MockRegistry,
    MockRouter
} from "./helpers/RoomsTest.sol";
import { RoundStatus } from "../src/shared/Types.sol";

contract RoomsSettlementTest is SettlementTest {
    function testPopulatedSuccessorUsesInheritedPotAndRollsOnlyDust() public {
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 3;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 first = open(v, 0, 10);
        finish(first, 1);
        assertEq(inspect.rollover(v), 15);
        uint256 id = open(v, 0, 3);
        buy(id, bob, 1, 1);
        finish(id, 0);
        Round memory r = inspect.roundState(id);
        assertEq(r.rolloverIn, 15);
        assertEq(r.receipts, 12);
        assertEq(r.payoutPerTicket, 7);
        assertEq(r.prizeRemaining, 21);
        assertEq(inspect.rollover(v), 0);
        assertEq(r.claimDeadline, uint256(r.settledAt) + 30 days);
        assertBacked(address(token));
        uint256 next = open(v, 0, 1);
        assertEq(inspect.roundState(next).rolloverIn, 0);
        assertBacked(address(token));
    }

    function testNonDivisiblePrizeDustAndDustOnlyOutcome() public {
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 1;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 id = open(v, 0, 3);
        buy(id, bob, 1, 1);
        finish(id, 0);
        Round memory r = inspect.roundState(id);
        assertEq(r.payoutPerTicket, 0);
        assertEq(r.prizeRemaining, 0);
        assertEq(inspect.rollover(v), 2);
        assertGt(r.claimDeadline, 0);
        assertBacked(address(token));
        id = open(v, 0, 3);
        buy(id, bob, 1, 4);
        finish(id, 0);
        r = inspect.roundState(id);
        assertEq(r.rolloverIn, 2);
        assertEq(r.payoutPerTicket, 1);
        assertEq(r.prizeRemaining, 3);
        assertEq(inspect.rollover(v), 2);
        assertBacked(address(token));
    }

    function testSettlementWhilePausedRemovedAndIntegrationsUnavailable() public {
        uint256 id = open(1, 0, 100);
        Round memory before = inspect.roundState(id);
        cacheForRoom(id, 0);
        gov.setPaused(true);
        gov.setAssetApproved(address(token), false);
        gov.setRoomsConfigEnabled(1, false);
        router.setReady(false);
        token.setFail(true);
        gov.setIntegrationConfig(
            IntegrationConfig(address(new MockRegistry()), address(new MockRouter()))
        );
        settlement.settleRound(id, hex"bad0");
        Round memory r = inspect.roundState(id);
        assertEq(uint256(r.status), uint256(RoundStatus.Settled));
        assertEq(r.deadlineDrandRound, before.deadlineDrandRound);
        assertEq(r.prizeRemaining, 50 ether);
        assertEq(inspect.bucket(1, address(token)), 20 ether);
        assertEq(inspect.bucket(2, address(token)), 0);
        assertBacked(address(token));
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotReady.selector, id));
        settlement.settleRound(id, "");
    }

    function testSelloutSettlementBeforeDeadlineAndDeadlineMixedReceipts() public {
        uint256 sold = open(1, 0, 100);
        uint64 deadline = inspect.roundState(sold).closesAt;
        finish(sold, 0);
        assertLt(block.timestamp, deadline);
        assertBacked(address(token));
        uint256 id = open(1, 0, 1);
        uint256 start = block.timestamp;
        vm.warp(start + 100);
        buy(id, bob, 1, 1);
        vm.warp(start + 200);
        buy(id, alice, 0, 1);
        vm.warp(start + 300);
        buy(id, bob, 1, 1);
        finish(id, 1);
        Round memory r = inspect.roundState(id);
        assertEq(r.receipts, 5.5 ether);
        assertEq(r.prizeRemaining, 2.75 ether);
        assertEq(r.effectiveClose, r.closesAt);
        assertBacked(address(token));
    }

    function testEmptyPublicSettlementHasNoDeadlineAndSuccessorConsumesOnce() public {
        uint256 id = open(1, 0, 10);
        finish(id, 1);
        Round memory r = inspect.roundState(id);
        assertEq(r.claimDeadline, 0);
        assertEq(r.prizeRemaining, 0);
        assertEq(inspect.rollover(1), 5 ether);
        assertBacked(address(token));
        id = open(1, 1, 1);
        assertEq(inspect.roundState(id).rolloverIn, 5 ether);
        assertEq(inspect.rollover(1), 0);
        assertBacked(address(token));
    }

    function testCachedZeroBeaconCompletesPublicSettlementWithoutProofOrDelivery() public {
        uint256 id = open(1, 0, 50);
        buy(id, bob, 1, 50);
        Round memory before = inspect.roundState(id);
        vm.warp(registry.roundTime(before.drandRound) + 1);
        registry.cache(before.drandRound, bytes32(0));
        registry.setBad(false, false, true);
        token.setFail(true);
        router.setReady(false);
        bytes32 expected = keccak256(abi.encode(bytes32(0), block.chainid, diamond, id));
        assertEq(settlement.settleRound(id, hex"bad0"), uint256(expected) % 2);
        Round memory r = inspect.roundState(id);
        assertEq(r.applicationSeed, expected);
        assertEq(r.prizeRemaining, 50 ether);
        assertEq(r.payoutPerTicket, 1 ether);
        assertEq(inspect.credit(address(token), address(this)), 1.5 ether);
        assertBacked(address(token));
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotReady.selector, id));
        settlement.settleRound(id, bytes(""));
        assertEq(inspect.roundState(id).prizeRemaining, 50 ether);
    }
}
