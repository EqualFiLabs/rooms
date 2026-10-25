// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ViewTest } from "./helpers/ViewTest.sol";
import { RoundPhase, Round, RoomsConfig } from "../src/shared/Types.sol";
import { Errors } from "../src/shared/Errors.sol";

contract RoomsViewsTest is ViewTest {
    function testQuoteTracksRoundedEpochPaymentAndMaximumProtection() public {
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 3;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 id = open(v, 0, 1);
        uint256 start = block.timestamp;
        for (uint8 e; e < 4; ++e) {
            vm.warp(start + uint256(e) * 100);
            (uint8 epoch, uint16 mult, uint256 unit, uint256 pay, uint256 remaining) =
                views.quotePurchase(id, 2);
            assertEq(epoch, e);
            assertEq(mult, 10_000 + uint256(e) * 2500);
            assertEq(unit, (3 * uint256(mult) + 9999) / 10_000);
            assertEq(pay, 2 * unit);
            assertEq(remaining, 100 - 1 - uint256(e) * 2);
            uint256 before = token.balanceOf(bob);
            vm.prank(bob);
            rooms.buyTickets(id, 1, 2, pay);
            assertEq(before - token.balanceOf(bob), pay);
        }
        uint256 other = open(1, 0, 1);
        (,,, uint256 quoted,) = views.quotePurchase(other, 1);
        vm.warp(block.timestamp + 100);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MaximumPaymentExceeded.selector, 1.25 ether, quoted)
        );
        rooms.buyTickets(other, 0, 1, quoted);
    }

    function testPhasesCutoffsAndEntitlementsThroughClaimsAndExpiry() public {
        assertEq(uint8(views.roundPhase(99)), uint8(RoundPhase.None));
        assertEq(views.claimablePrize(99, alice), 0);
        uint256 id = fundedPrize();
        assertEq(uint8(views.roundPhase(id)), uint8(RoundPhase.Settled));
        assertEq(views.claimablePrize(id, alice), 30 ether);
        vm.prank(alice);
        claims.claimPrize(id, alice);
        assertEq(views.claimablePrize(id, alice), 0);
        assertTrue(views.prizeClaimed(id, alice));
        assertEq(views.userRoomTicketCount(id, 0, alice), 30);
        assertEq(views.roomTicketCounts(id)[0], 50);
        vm.warp(views.round(id).claimDeadline);
        assertEq(views.claimablePrize(id, bob), 0);
        claims.expirePrize(id);
        (uint256 balance, uint256 accounted) = views.assetBalanceAndAccounted(address(token));
        assertEq(balance, accounted);
        token.mint(diamond, 7);
        (balance, accounted) = views.assetBalanceAndAccounted(address(token));
        assertEq(balance - accounted, 7);
        uint256 deadline = open(1, 0, 1);
        assertEq(uint8(views.roundPhase(deadline)), uint8(RoundPhase.Open));
        vm.warp(views.round(deadline).closesAt);
        assertEq(uint8(views.roundPhase(deadline)), uint8(RoundPhase.Locked));
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotOpen.selector, deadline));
        views.quotePurchase(deadline, 1);
        RoomsConfig memory c = fixture();
        c.ticketSupply = 1;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 sold = open(v, 1, 1);
        assertEq(uint8(views.roundPhase(sold)), uint8(RoundPhase.SoldOut));
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotOpen.selector, sold));
        views.quotePurchase(sold, 1);
    }
}
