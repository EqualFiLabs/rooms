// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { LifecycleTest } from "./helpers/LifecycleTest.sol";
import { TestToken, RoomsConfig, Round, AssetAccounting, Errors } from "./helpers/RoomsTest.sol";
import { RoundStatus } from "../src/shared/Types.sol";

contract SixDecimalToken is TestToken {
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract RoomsOpeningIntegrationTest is LifecycleTest {
    function testConcurrentAssetsPricesAdmissionAndBothCutoffs() public {
        SixDecimalToken other = new SixDecimalToken();
        other.mint(alice, 100_000_000);
        other.mint(bob, 100_000_000);
        vm.prank(alice);
        other.approve(diamond, type(uint256).max);
        vm.prank(bob);
        other.approve(diamond, type(uint256).max);
        gov.setAssetApproved(address(other), true);
        RoomsConfig memory c = fixture();
        c.paymentToken = address(other);
        c.baseTicketPrice = 1_000_001;
        c.roomCount = 7;
        c.ticketSupply = 5;
        c.maxTicketsPerPurchase = 2;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 original = open(1, 0, 1);
        uint256 id = open(v, 6, 1);
        Round memory first = inspect.roundState(id);
        uint256 start = block.timestamp;
        gov.setRoomsConfigEnabled(v, false);
        buy(id, bob, 1, 1); // Disabling a config affects opening, not the snapshotted active round.
        vm.warp(start + 100);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MaximumPaymentExceeded.selector, uint256(1_250_002), uint256(1_000_001)
            )
        );
        rooms.buyTickets(id, 6, 1, 1_000_001);
        vm.expectRevert(Errors.TicketLimitExceeded.selector);
        vm.prank(alice);
        rooms.buyTickets(id, 6, 3, type(uint256).max);
        buy(id, alice, 6, 1);
        gov.setPaused(true);
        vm.expectRevert(Errors.ProtocolPaused.selector);
        vm.prank(bob);
        rooms.buyTickets(id, 1, 1, type(uint256).max);
        gov.setPaused(false);
        gov.setAssetApproved(address(other), false);
        vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotApproved.selector, address(other)));
        vm.prank(bob);
        rooms.buyTickets(id, 1, 1, type(uint256).max);
        gov.setAssetApproved(address(other), true);
        vm.warp(start + 200);
        buy(id, bob, 1, 1);
        vm.warp(start + 300);
        buy(id, alice, 6, 1);
        Round memory sold = inspect.roundState(id);
        assertEq(sold.receipts, 2_000_002 + 1_250_002 + 1_500_002 + 1_750_002);
        assertEq(sold.totalTickets, 5);
        assertEq(sold.config.roomCount, 7);
        assertEq(sold.deadlineDrandRound, first.deadlineDrandRound);
        assertEq(uint256(sold.status), uint256(RoundStatus.SoldOut));
        assertEq(other.balanceOf(diamond), sold.receipts);
        AssetAccounting memory a = inspect.accounting(address(other));
        assertEq(a.activeRoundEscrow, sold.receipts);
        assertEq(inspect.accounting(address(token)).activeRoundEscrow, 1 ether);
        vm.warp(start + 400);
        Round memory locked = inspect.roundState(original);
        assertEq(uint256(locked.status), uint256(RoundStatus.Open));
        assertEq(locked.effectiveClose, locked.closesAt);
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotOpen.selector, original));
        rooms.buyTickets(original, 0, 1, 2 ether);
        (, uint256 active,,,) = inspect.state();
        assertEq(active, 2);
        (uint256 total, uint256 held) = inspect.tickets(id, 6, alice);
        assertEq(total, 3);
        assertEq(held, 3);
    }

    function testPublicPricePartitionAndFullWidthReceipts() public {
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 1;
        c.ticketSupply = type(uint256).max;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        uint256 id = open(v, 0, 1);
        vm.warp(block.timestamp + 100);
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);
        buy(id, alice, 0, 3);
        buy(id, bob, 1, 1);
        buy(id, bob, 1, 2);
        assertEq(aliceBefore - token.balanceOf(alice), bobBefore - token.balanceOf(bob));
        uint256 q = uint256(1) << 130;
        token.mint(alice, q * 2);
        buy(id, alice, 0, q);
        assertEq(inspect.roundState(id).receipts, 13 + q * 2);
        assertEq(inspect.accounting(address(token)).activeRoundEscrow, token.balanceOf(diamond));
    }

    function testOpeningFailureRestoresCapacityAndSubsequentIdentifier() public {
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        vm.prank(alice);
        rooms.openRound(1, 0, 1, 1 ether);
        assertEq(inspect.activeFor(1), 0);
        (, uint256 active,,,) = inspect.state();
        assertEq(active, 0);
        token.setFail(false);
        uint256 id = open(1, 0, 1);
        assertEq(id, 1);
        uint64 target = inspect.roundState(id).drandRound;
        gov.setRoomsConfigEnabled(1, false);
        buy(id, bob, 1, 1);
        assertEq(inspect.roundState(id).drandRound, target);
    }
}
