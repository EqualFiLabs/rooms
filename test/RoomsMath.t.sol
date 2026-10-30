// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { Test } from "forge-std/Test.sol";
import { LibRoomsMath as M } from "../src/libraries/LibRoomsMath.sol";
import { RoomsConfig, Allocations } from "../src/shared/Types.sol";

contract RoomsMathTest is Test {
    function testFuzzAllocationConservationFullWidth(uint256 gross, uint16 p, uint16 o, uint16 tip)
        public
        pure
    {
        RoomsConfig memory c;
        c.potBps = uint16(bound(p, 1, 9999));
        c.operatorBps = uint16(bound(o, 0, 9999 - c.potBps));
        c.settlementTipBps = uint16(bound(tip, 0, 9999));
        Allocations memory a = M.allocate(gross, c);
        assertEq(a.pot + a.operatorRevenue + a.finalizerTip + a.treasuryNet, gross);
        assertEq(a.treasuryGross, a.finalizerTip + a.treasuryNet);
        if (gross != 0) assertGt(a.treasuryNet, 0);
    }

    function testFuzzPerTicketAndWalletPartition(uint256 pot, uint256 tickets, uint256 left)
        public
        pure
    {
        tickets = bound(tickets, 1, type(uint256).max);
        left = bound(left, 0, tickets);
        (uint256 unit, uint256 distributed, uint256 dust) = M.perTicket(pot, tickets);
        assertEq(distributed + dust, pot);
        assertLt(dust, tickets);
        assertEq(unit * left + unit * (tickets - left), distributed);
    }

    function testFuzzEpochAndPartition(
        uint96 base,
        uint32 duration,
        uint32 elapsed,
        uint32 quantity
    ) public pure {
        duration = uint32(bound(duration, 4, type(uint32).max));
        elapsed = uint32(bound(elapsed, 0, uint256(duration) - 1));
        uint8 e = M.epoch(elapsed, duration);
        assertLe(e, 3);
        uint256 unit = M.unitPrice(base, e);
        uint256 product = uint256(base) * M.multiplier(e);
        assertGe(unit * 10_000, product);
        if (unit != 0) assertLt((unit - 1) * 10_000, product);
        uint256 left = uint256(quantity) / 2;
        assertEq(unit * left + unit * (quantity - left), unit * quantity);
    }

    function testTreasuryDenominatorAndTinyAmounts() public pure {
        RoomsConfig memory c;
        c.potBps = 5000;
        c.operatorBps = 2000;
        c.settlementTipBps = 500;
        Allocations memory a = M.allocate(10_000, c);
        assertEq(a.finalizerTip, 150);
        assertEq(a.treasuryNet, 2850);
        a = M.allocate(1, c);
        assertEq(a.pot, 0);
        assertEq(a.operatorRevenue, 0);
        assertEq(a.finalizerTip, 0);
        assertEq(a.treasuryNet, 1);
        (uint256 unit, uint256 distributed, uint256 dust) = M.perTicket(7, 10);
        assertEq(unit, 0);
        assertEq(distributed, 0);
        assertEq(dust, 7);
        (unit, distributed, dust) = M.perTicket(7, 0);
        assertEq(unit, 0);
        assertEq(distributed, 0);
        assertEq(dust, 7);
    }
}
