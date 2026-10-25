// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ClaimsTest } from "./helpers/ClaimsTest.sol";
import { RoomsConfig, TestToken, Errors } from "./helpers/RoomsTest.sol";

contract RoomsFinalizerClaimsTest is ClaimsTest {
    function testAggregatesAcrossRoundsDoesNotExpireAndIgnoresAdmission() public {
        uint256 id = fundedPrize();
        uint256 credit = inspect.credit(address(token), address(this));
        uint256 second = open(1, 0, 10);
        finish(second, 1);
        credit += 0.15 ether;
        assertEq(inspect.credit(address(token), address(this)), credit);
        gov.setPaused(true);
        gov.setAssetApproved(address(token), false);
        vm.warp(uint256(inspect.roundState(id).claimDeadline) + 365 days);
        uint256 before = token.balanceOf(alice);
        assertEq(claims.claimFinalizerTips(address(token), alice), credit);
        assertEq(token.balanceOf(alice), before + credit);
        assertEq(inspect.credit(address(token), address(this)), 0);
        assertEq(inspect.accounting(address(token)).finalizerLiability, 0);
        assertBacked(address(token));
        vm.expectRevert(Errors.NoFinalizerCredit.selector);
        claims.claimFinalizerTips(address(token), alice);
    }

    function testCreditTransferFailureReceiverValidationAndReentry() public {
        fundedPrize();
        uint256 credit = inspect.credit(address(token), address(this));
        vm.expectRevert(Errors.InvalidAddress.selector);
        claims.claimFinalizerTips(address(token), diamond);
        vm.expectRevert(Errors.InvalidAddress.selector);
        claims.claimFinalizerTips(address(token), address(0));
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        claims.claimFinalizerTips(address(token), alice);
        assertEq(inspect.credit(address(token), address(this)), credit);
        token.setFail(false);
        token.setCallback(
            diamond, abi.encodeCall(claims.claimFinalizerTips, (address(token), alice))
        );
        claims.claimFinalizerTips(address(token), alice);
        assertFalse(token.callbackSucceeded());
        assertEq(bytes4(token.callbackResult()), Errors.Reentrancy.selector);
        assertBacked(address(token));
    }

    function testDifferentFinalizersAndAssetsRemainIndependent() public {
        uint256 first = open(1, 0, 100);
        cacheForRoom(first, 0);
        vm.prank(bob);
        settlement.settleRound(first, "");
        TestToken other = new TestToken();
        gov.setAssetApproved(address(other), true);
        other.mint(alice, 100 ether);
        vm.prank(alice);
        other.approve(diamond, type(uint256).max);
        RoomsConfig memory c = fixture();
        c.paymentToken = address(other);
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 id = open(v, 0, 100);
        finish(id, 0);
        assertEq(inspect.credit(address(token), bob), 1.5 ether);
        assertEq(inspect.credit(address(other), address(this)), 1.5 ether);
        vm.expectRevert(Errors.NoFinalizerCredit.selector);
        claims.claimFinalizerTips(address(token), alice);
        claims.claimFinalizerTips(address(other), alice);
        assertEq(inspect.credit(address(token), bob), 1.5 ether);
        vm.prank(bob);
        claims.claimFinalizerTips(address(token), bob);
        assertBacked(address(token));
        assertBacked(address(other));
    }
}
