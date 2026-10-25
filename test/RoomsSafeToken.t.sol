// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ViewTest } from "./helpers/ViewTest.sol";
import { TestToken } from "./helpers/RoomsTest.sol";
import { RoomsConfig } from "../src/shared/Types.sol";

contract ReportingFailureToken is TestToken {
    bool public reportsFailure;

    function setReportsFailure(bool value) external {
        reportsFailure = value;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (reportsFailure) return false;
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (reportsFailure) return false;
        return super.transferFrom(from, to, amount);
    }
}

contract RoomsSafeTokenTest is ViewTest {
    function testFalseReturnPreservesOpeningClaimAndRevenueRetry() public {
        ReportingFailureToken t = new ReportingFailureToken();
        gov.setAssetApproved(address(t), true);
        RoomsConfig memory c = fixture();
        c.paymentToken = address(t);
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        t.mint(alice, 100 ether);
        vm.prank(alice);
        t.approve(diamond, type(uint256).max);
        t.setReportsFailure(true);
        vm.expectRevert();
        vm.prank(alice);
        rooms.openRound(v, 0, 100, type(uint256).max);
        assertEq(views.activeRoundForConfig(v), 0);
        assertEq(views.activeRoundCount(), 0);
        assertEq(t.balanceOf(diamond), 0);
        t.setReportsFailure(false);
        uint256 id = open(v, 0, 100);
        finish(id, 0);
        uint256 prize = views.claimablePrize(id, alice);
        uint256 op = views.pendingOperatorRevenue(1, address(t));
        t.setReportsFailure(true);
        vm.expectRevert();
        vm.prank(alice);
        claims.claimPrize(id, alice);
        assertEq(views.claimablePrize(id, alice), prize);
        vm.expectRevert();
        revenue.flushOperatorRevenue(1, address(t), op);
        assertEq(views.pendingOperatorRevenue(1, address(t)), op);
        assertEq(t.allowance(diamond, address(router)), 0);
        uint256 treasuryAmount = views.assetAccounting(address(t)).treasuryAvailable;
        vm.expectRevert();
        revenue.flushTreasury(address(t), treasuryAmount);
        assertEq(views.assetAccounting(address(t)).treasuryAvailable, treasuryAmount);
        t.setReportsFailure(false);
        vm.prank(alice);
        assertEq(claims.claimPrize(id, alice), prize);
        revenue.flushOperatorRevenue(1, address(t), op);
        revenue.flushTreasury(address(t), treasuryAmount);
        assertBacked(address(t));
    }
}
