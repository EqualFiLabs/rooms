// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ClaimsTest } from "./helpers/ClaimsTest.sol";
import { RoomsConfig, Round, AssetAccounting, Errors } from "./helpers/RoomsTest.sol";

contract RoomsExpiryTest is ClaimsTest {
    function testStrictBoundaryPartialClaimAndOneShotExpiry() public {
        uint256 id = fundedPrize();
        uint256 deadline = inspect.roundState(id).claimDeadline;
        vm.expectRevert(Errors.PrizeNotExpired.selector);
        claims.expirePrize(id);
        vm.warp(deadline - 1);
        vm.prank(alice);
        claims.claimPrize(id, alice);
        vm.warp(deadline);
        vm.prank(bob);
        vm.expectRevert(Errors.PrizeExpired.selector);
        claims.claimPrize(id, bob);
        AssetAccounting memory before = inspect.accounting(address(token));
        assertEq(before.prizeLiability, 20 ether);
        assertBacked(address(token));
        token.setFail(true);
        assertEq(claims.expirePrize(id), 20 ether);
        AssetAccounting memory after_ = inspect.accounting(address(token));
        assertEq(after_.treasuryAvailable, before.treasuryAvailable + 20 ether);
        assertEq(after_.prizeLiability, 0);
        assertEq(after_.pendingOperatorRevenueTotal, before.pendingOperatorRevenueTotal);
        assertEq(after_.finalizerLiability, before.finalizerLiability);
        assertTrue(inspect.roundState(id).prizeExpired);
        assertEq(inspect.roundState(id).prizeRemaining, 0);
        assertBacked(address(token));
        vm.expectRevert(Errors.PrizeAlreadyExpired.selector);
        claims.expirePrize(id);
        vm.prank(bob);
        vm.expectRevert(Errors.PrizeExpired.selector);
        claims.claimPrize(id, bob);
    }

    function testZeroAndAllClaimsExpiryAndEmptyExclusion() public {
        uint256 id = fundedPrize();
        vm.prank(alice);
        claims.claimPrize(id, alice);
        vm.prank(bob);
        claims.claimPrize(id, bob);
        vm.warp(inspect.roundState(id).claimDeadline);
        assertEq(claims.expirePrize(id), 0);
        assertBacked(address(token));
        id = open(1, 0, 1);
        finish(id, 1);
        vm.expectRevert(Errors.EmptyWinningRoom.selector);
        claims.expirePrize(id);
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 1;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        id = open(v, 0, 3);
        finish(id, 0);
        assertGt(inspect.rollover(v), 0);
        vm.warp(inspect.roundState(id).claimDeadline);
        assertEq(claims.expirePrize(id), 0);
        assertEq(inspect.rollover(v), 1);
        assertBacked(address(token));
    }

    function testDelayedSettlementKeepsFullWindowAndAdmissionCannotBlockExpiry() public {
        uint256 id = open(1, 0, 10);
        Round memory initial = inspect.roundState(id);
        vm.warp(uint256(initial.closesAt) + 100 days);
        finish(id, 0);
        Round memory r = inspect.roundState(id);
        assertEq(r.claimDeadline, block.timestamp + 30 days);
        gov.setPaused(true);
        gov.setRoomsConfigEnabled(1, false);
        gov.setAssetApproved(address(token), false);
        vm.warp(r.claimDeadline);
        assertEq(claims.expirePrize(id), 5 ether);
        assertBacked(address(token));
    }
}
