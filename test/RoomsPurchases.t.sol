// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { GovernanceTest } from "./helpers/GovernanceTest.sol";
import { RoomsConfig, Round, Errors } from "./helpers/RoomsTest.sol";
import { RoundStatus } from "../src/shared/Types.sol";
import { LibRoomsStorage as S } from "../src/libraries/LibRoomsStorage.sol";
import { LibRoomsPurchase } from "../src/libraries/LibRoomsPurchase.sol";
import { Guarded } from "../src/shared/Guarded.sol";

/// @dev Isolates internal price/count logic before the complete public lifecycle is installed.
contract PurchaseHarness is Guarded {
    function seed(RoomsConfig calldata c) external {
        Round storage r = S.gameStorage().rounds[1];
        r.config = c;
        r.openedAt = uint64(block.timestamp);
        r.closesAt = uint64(block.timestamp + c.salesDuration);
        r.status = RoundStatus.Open;
    }

    function purchase(uint8 room, uint256 quantity, uint256 maximum) external nonReentrant {
        LibRoomsPurchase.record(1, room, quantity, maximum);
    }
}

contract RoomsPurchasesTest is GovernanceTest {
    PurchaseHarness internal h;

    function setUp() public override {
        super.setUp();
        bytes4[] memory s = new bytes4[](2);
        s[0] = PurchaseHarness.seed.selector;
        s[1] = PurchaseHarness.purchase.selector;
        install(address(new PurchaseHarness()), s);
        h = PurchaseHarness(diamond);
        h.seed(fixture());
    }

    function buy(address user, uint8 room, uint256 q, uint256 maximum) internal {
        vm.prank(user);
        h.purchase(room, q, maximum);
    }

    function testEpochBoundaryAndReceipts() public {
        uint256 start = block.timestamp;
        for (uint256 e; e < 4; ++e) {
            vm.warp(start + e * 100);
            buy(alice, 0, 1, type(uint256).max);
            if (e < 3) {
                vm.warp(start + (e + 1) * 100 - 1);
                buy(bob, 1, 1, type(uint256).max);
            }
        }
        Round memory r = inspect.roundState(1);
        assertEq(r.totalTickets, 7);
        assertEq(r.receipts, 2 ether + 2.5 ether + 3 ether + 1.75 ether);
        assertEq(token.balanceOf(diamond), r.receipts);
        vm.warp(start + 400);
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotOpen.selector, 1));
        h.purchase(0, 1, 2 ether);
    }

    function testRoundedUnitsAndPartitionNeutrality() public {
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 1;
        h.seed(c);
        vm.warp(block.timestamp + 100);
        buy(alice, 0, 3, 6);
        buy(bob, 1, 1, 2);
        buy(bob, 1, 2, 4);
        Round memory r = inspect.roundState(1);
        assertEq(r.receipts, 12);
        (uint256 a,) = inspect.tickets(1, 0, alice);
        (uint256 b,) = inspect.tickets(1, 1, bob);
        assertEq(a, b);
    }

    function testNonDivisibleEpochsMaximumAndWidePrice() public {
        RoomsConfig memory c = fixture();
        c.salesDuration = 7;
        c.baseTicketPrice = type(uint96).max;
        h.seed(c);
        uint256 start = block.timestamp;
        vm.warp(start + 1);
        buy(alice, 0, 1, type(uint96).max);
        vm.warp(start + 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MaximumPaymentExceeded.selector,
                (uint256(c.baseTicketPrice) * 12_500 + 9999) / 10_000,
                uint256(c.baseTicketPrice)
            )
        );
        vm.prank(alice);
        h.purchase(0, 1, c.baseTicketPrice);
        vm.warp(start + 6);
        buy(alice, 0, 1, type(uint256).max);
        assertGt(inspect.roundState(1).receipts, uint256(type(uint96).max) * 2);
    }

    function testSupplyLimitsAndFailureRollback() public {
        buy(alice, 0, 99, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientSupply.selector, 2, 1));
        vm.prank(bob);
        h.purchase(1, 2, type(uint256).max);
        assertEq(inspect.roundState(1).totalTickets, 99);
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        vm.prank(bob);
        h.purchase(1, 1, type(uint256).max);
        assertEq(inspect.roundState(1).totalTickets, 99);
        assertEq(token.balanceOf(diamond), 99 ether);
        token.setFail(false);
        buy(bob, 1, 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientSupply.selector, 1, 0));
        vm.prank(alice);
        h.purchase(0, 1, type(uint256).max);
    }

    function testWideReceiptsBeyondUint128() public {
        RoomsConfig memory c = fixture();
        c.ticketSupply = uint256(1) << 160;
        c.baseTicketPrice = 1;
        h.seed(c);
        uint256 q = uint256(1) << 130;
        token.mint(alice, q);
        buy(alice, 0, q, q);
        assertEq(inspect.roundState(1).receipts, q);
        assertEq(inspect.accounting(address(token)).activeRoundEscrow, q);
    }

    function testAdmissionPauseRoomAndQuantity() public {
        vm.expectRevert(Errors.InvalidTicketQuantity.selector);
        h.purchase(0, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRoom.selector, uint8(2)));
        h.purchase(2, 1, 1 ether);
        gov.setPaused(true);
        vm.expectRevert(Errors.ProtocolPaused.selector);
        h.purchase(0, 1, 1 ether);
        gov.setPaused(false);
        gov.setAssetApproved(address(token), false);
        vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotApproved.selector, address(token)));
        h.purchase(0, 1, 1 ether);
    }
}
