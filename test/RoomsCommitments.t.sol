// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { LifecycleTest } from "./helpers/LifecycleTest.sol";
import { RoomsConfig, Round, Errors, InspectFacet } from "./helpers/RoomsTest.sol";
import { RoundStatus } from "../src/shared/Types.sol";

contract RoomsCommitmentsTest is LifecycleTest {
    function testSelloutEveryEpochRetainsOriginalAndCapacity() public {
        for (uint256 e; e < 4; ++e) {
            uint64 v = gov.createRoomsConfig(fixture());
            gov.setRoomsConfigEnabled(v, true);
            uint256 id = open(v, 0, 1);
            Round memory before = inspect.roundState(id);
            vm.warp(block.timestamp + e * 100);
            buy(id, bob, 1, 99);
            Round memory r = inspect.roundState(id);
            assertEq(uint256(r.status), uint256(RoundStatus.SoldOut));
            assertEq(r.deadlineDrandRound, before.deadlineDrandRound);
            assertEq(r.closesAt, before.closesAt);
            assertEq(r.soldOutAt, block.timestamp);
            assertEq(r.effectiveClose, r.soldOutAt);
            assertEq(r.drandRound, registry.firstRoundAfter(block.timestamp + 30));
            assertEq(inspect.activeFor(v), id);
            vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotOpen.selector, id));
            rooms.buyTickets(id, 0, 1, 1 ether);
        }
        (, uint256 active,,,) = inspect.state();
        assertEq(active, 4);
    }

    function testFirstPurchaseSelloutAndSameTarget() public {
        uint256 id = open(1, 0, 100);
        Round memory r = inspect.roundState(id);
        assertEq(uint256(r.status), uint256(RoundStatus.SoldOut));
        assertLt(r.drandRound, r.deadlineDrandRound);
        RoomsConfig memory c = fixture();
        c.salesDuration = 4;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 next = open(v, 0, 1);
        Round memory initial = inspect.roundState(next);
        vm.warp(uint256(initial.closesAt) - 1);
        buy(next, bob, 1, 99);
        r = inspect.roundState(next);
        assertEq(r.drandRound, r.deadlineDrandRound);
    }

    function testDeadlineLocksWithoutReselection() public {
        uint256 id = open(1, 0, 1);
        Round memory initial = inspect.roundState(id);
        vm.warp(initial.closesAt);
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotOpen.selector, id));
        rooms.buyTickets(id, 0, 99, type(uint256).max);
        Round memory r = inspect.roundState(id);
        assertEq(r.drandRound, initial.drandRound);
        assertEq(uint256(r.status), uint256(RoundStatus.Open));
        assertEq(r.effectiveClose, r.closesAt);
    }

    function testSelectedTargetValidationAndAtomicRollback() public {
        uint256 id = open(1, 0, 1);
        Round memory initial = inspect.roundState(id);
        registry.setBad(true, false, false);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRandomnessRound.selector, uint64(0)));
        vm.prank(bob);
        rooms.buyTickets(id, 1, 99, type(uint256).max);
        assertEq(inspect.roundState(id).totalTickets, 1);
        assertEq(token.balanceOf(diamond), 1 ether);
        assertEq(inspect.roundState(id).drandRound, initial.drandRound);
        registry.setBad(false, true, false);
        uint64 target = registry.firstRoundAfter(block.timestamp + 30);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRandomnessRound.selector, target));
        vm.prank(bob);
        rooms.buyTickets(id, 1, 99, type(uint256).max);
        registry.setBad(false, false, false);
        registry.cache(target, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.StaleRandomnessRound.selector, target));
        vm.prank(bob);
        rooms.buyTickets(id, 1, 99, type(uint256).max);
        assertEq(inspect.roundState(id).totalTickets, 1);
    }

    function testOpeningStaleCommitmentAndTransferFailureRollback() public {
        uint64 target = registry.firstRoundAfter(block.timestamp + 430);
        registry.cache(target, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.StaleRandomnessRound.selector, target));
        vm.prank(alice);
        rooms.openRound(1, 0, 1, type(uint256).max);
        assertEq(inspect.activeFor(1), 0);
        assertEq(token.balanceOf(diamond), 0);
        vm.warp(block.timestamp + 3);
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        vm.prank(alice);
        rooms.openRound(1, 0, 100, type(uint256).max);
        assertEq(inspect.activeFor(1), 0);
        assertEq(inspect.roundState(1).totalTickets, 0);
    }

    function testFinalTransferFailureAndSharedGuard() public {
        uint256 id = open(1, 0, 1);
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        vm.prank(bob);
        rooms.buyTickets(id, 1, 99, type(uint256).max);
        assertEq(inspect.roundState(id).totalTickets, 1);
        token.setFail(false);
        token.setCallback(diamond, abi.encodeCall(rooms.buyTickets, (id, 0, 1, type(uint256).max)));
        buy(id, bob, 1, 99);
        assertFalse(token.callbackSucceeded());
        assertEq(uint256(inspect.roundState(id).status), uint256(RoundStatus.SoldOut));
    }

    function testPurchaseCeilingAndUnrepresentablePaymentRollback() public {
        RoomsConfig memory c = fixture();
        c.maxTicketsPerPurchase = 2;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 id = open(v, 0, 1);
        vm.expectRevert(Errors.TicketLimitExceeded.selector);
        vm.prank(bob);
        rooms.buyTickets(id, 0, 3, type(uint256).max);
        assertEq(inspect.roundState(id).totalTickets, 1);
        c = fixture();
        c.ticketSupply = type(uint256).max;
        c.baseTicketPrice = type(uint96).max;
        v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        vm.prank(alice);
        rooms.openRound(v, 0, uint256(1) << 200, type(uint256).max);
        assertEq(inspect.activeFor(v), 0);
    }

    function testTokenCallbackObservesCommittedSellout() public {
        uint256 id = open(1, 0, 1);
        token.setCallback(diamond, abi.encodeCall(InspectFacet.roundState, (id)));
        buy(id, bob, 1, 99);
        assertTrue(token.callbackSucceeded());
        Round memory observed = abi.decode(token.callbackResult(), (Round));
        assertEq(uint256(observed.status), uint256(RoundStatus.SoldOut));
        assertEq(observed.drandRound, registry.firstRoundAfter(block.timestamp + 30));
        assertEq(observed.effectiveClose, block.timestamp);
    }
}
