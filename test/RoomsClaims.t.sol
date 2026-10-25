// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ClaimsTest } from "./helpers/ClaimsTest.sol";
import { RoomsConfig, Round, Errors } from "./helpers/RoomsTest.sol";

contract RoomsClaimsTest is ClaimsTest {
    function testOneShotReceiverClaimsRetainTicketHistory() public {
        uint256 id = fundedPrize();
        uint256 before = token.balanceOf(bob);
        vm.prank(alice);
        assertEq(claims.claimPrize(id, bob), 30 ether);
        assertEq(token.balanceOf(bob), before + 30 ether);
        (uint256 total, uint256 held) = inspect.tickets(id, 0, alice);
        assertEq(total, 50);
        assertEq(held, 30);
        vm.prank(alice);
        vm.expectRevert(Errors.PrizeAlreadyClaimed.selector);
        claims.claimPrize(id, alice);
        vm.prank(bob);
        assertEq(claims.claimPrize(id, bob), 20 ether);
        assertEq(inspect.roundState(id).prizeRemaining, 0);
        assertBacked(address(token));
    }

    function testTransferFailureAndReentryPreserveRetryAndOthers() public {
        uint256 id = fundedPrize();
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        vm.prank(alice);
        claims.claimPrize(id, alice);
        assertEq(inspect.roundState(id).prizeRemaining, 50 ether);
        assertEq(inspect.accounting(address(token)).prizeLiability, 50 ether);
        token.setFail(false);
        token.setCallback(diamond, abi.encodeCall(claims.claimPrize, (id, alice)));
        vm.prank(bob);
        claims.claimPrize(id, bob);
        assertFalse(token.callbackSucceeded());
        assertEq(bytes4(token.callbackResult()), Errors.Reentrancy.selector);
        vm.prank(alice);
        claims.claimPrize(id, alice);
        assertBacked(address(token));
    }

    function testClaimsIgnorePauseDisableAndRemovalAndValidateEntitlement() public {
        uint256 id = fundedPrize();
        gov.setPaused(true);
        gov.setRoomsConfigEnabled(1, false);
        gov.setAssetApproved(address(token), false);
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidAddress.selector);
        claims.claimPrize(id, address(0));
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidAddress.selector);
        claims.claimPrize(id, diamond);
        vm.expectRevert(Errors.NoPrize.selector);
        claims.claimPrize(id, treasury);
        vm.prank(alice);
        claims.claimPrize(id, alice);
        vm.prank(bob);
        claims.claimPrize(id, bob);
        assertBacked(address(token));
    }

    function testEqualWeightAcrossPricesAndZeroPayoutRejected() public {
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 3;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 id = open(v, 0, 3);
        vm.warp(block.timestamp + 300);
        buy(id, bob, 0, 2);
        finish(id, 0);
        Round memory r = inspect.roundState(id);
        assertEq(r.receipts, 21);
        assertEq(r.payoutPerTicket, 2);
        vm.prank(bob);
        assertEq(claims.claimPrize(id, bob), 4);
        vm.prank(alice);
        assertEq(claims.claimPrize(id, alice), 6);
        assertBacked(address(token));
        c.baseTicketPrice = 1;
        v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        id = open(v, 0, 3);
        finish(id, 0);
        vm.prank(alice);
        vm.expectRevert(Errors.NoPrize.selector);
        claims.claimPrize(id, alice);
        assertEq(inspect.roundState(id).prizeRemaining, 0);
        assertBacked(address(token));
    }

    function testFuzzWalletPartitionAndClaimOrder(uint8 left, uint8 right, bool reverse) public {
        left = uint8(bound(left, 1, 40));
        right = uint8(bound(right, 1, 40));
        uint256 id = open(1, 0, left);
        buy(id, bob, 0, right);
        buy(id, alice, 1, 1);
        finish(id, 0);
        uint256 expected = inspect.roundState(id).prizeRemaining;
        uint256 paid;
        if (reverse) {
            vm.prank(bob);
            paid = claims.claimPrize(id, bob);
            vm.prank(alice);
            paid += claims.claimPrize(id, alice);
        } else {
            vm.prank(alice);
            paid = claims.claimPrize(id, alice);
            vm.prank(bob);
            paid += claims.claimPrize(id, bob);
        }
        assertEq(paid, expected);
        assertBacked(address(token));
    }
}
