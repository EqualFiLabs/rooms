// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { GovernanceTest } from "./helpers/GovernanceTest.sol";
import { RoomsConfig, Errors } from "./helpers/RoomsTest.sol";

contract RoomsConfigTest is GovernanceTest {
    function testImmutableVersionsDisabledByDefault() public {
        RoomsConfig memory c = fixture();
        c.roomCount = 7;
        uint64 v = gov.createRoomsConfig(c);
        assertEq(v, 2);
        (RoomsConfig memory stored, bool enabled) = inspect.config(v);
        assertEq(stored.roomCount, 7);
        assertFalse(enabled);
        gov.setRoomsConfigEnabled(v, true);
        c.baseTicketPrice = 2 ether;
        gov.createRoomsConfig(c);
        (stored, enabled) = inspect.config(v);
        assertTrue(enabled);
        assertEq(stored.baseTicketPrice, 1 ether);
    }

    function testArbitraryRoomCountsAndFullWidthSupply() public {
        RoomsConfig memory c = fixture();
        c.ticketSupply = type(uint256).max;
        c.roomCount = 3;
        gov.createRoomsConfig(c);
        c.roomCount = 7;
        gov.createRoomsConfig(c);
        c.roomCount = 24;
        c.salesDuration = 4;
        c.maxTicketsPerPurchase = type(uint32).max;
        gov.createRoomsConfig(c);
    }

    function testInvalidBoundsAndWidenedBps() public {
        RoomsConfig memory c = fixture();
        c.roomCount = 1;
        bad(c);
        c.roomCount = 25;
        bad(c);
        c = fixture();
        c.salesDuration = 3;
        bad(c);
        c = fixture();
        c.baseTicketPrice = 0;
        bad(c);
        c = fixture();
        c.ticketSupply = 0;
        bad(c);
        c = fixture();
        c.potBps = 0;
        bad(c);
        c = fixture();
        c.potBps = 8000;
        c.operatorBps = 2000;
        bad(c);
        c.potBps = 65_535;
        c.operatorBps = 65_535;
        bad(c);
        c = fixture();
        c.settlementTipBps = 10_000;
        bad(c);
    }

    function testAuthorityAndMissingConfiguration() public {
        RoomsConfig memory c = fixture();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAuthority.selector, alice));
        gov.createRoomsConfig(c);
        vm.expectRevert(abi.encodeWithSelector(Errors.ConfigNotFound.selector, uint64(0)));
        gov.setRoomsConfigEnabled(0, true);
    }

    function testFuzzValidEconomicBoundaries(uint16 p, uint16 o, uint16 tip, uint8 rooms) public {
        RoomsConfig memory c = fixture();
        c.potBps = uint16(bound(p, 1, 9999));
        c.operatorBps = uint16(bound(o, 0, 9999 - c.potBps));
        c.settlementTipBps = uint16(bound(tip, 0, 9999));
        c.roomCount = uint8(bound(rooms, 2, 24));
        gov.createRoomsConfig(c);
    }

    function bad(RoomsConfig memory c) internal {
        vm.expectRevert(Errors.InvalidConfig.selector);
        gov.createRoomsConfig(c);
    }
}
