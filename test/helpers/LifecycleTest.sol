// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { GovernanceTest } from "./GovernanceTest.sol";
import { RoomsFacet } from "../../src/facets/RoomsFacet.sol";

abstract contract LifecycleTest is GovernanceTest {
    RoomsFacet internal rooms;

    function setUp() public virtual override {
        super.setUp();
        bytes4[] memory s = new bytes4[](2);
        s[0] = RoomsFacet.openRound.selector;
        s[1] = RoomsFacet.buyTickets.selector;
        install(address(new RoomsFacet()), s);
        rooms = RoomsFacet(diamond);
    }

    function open(uint64 v, uint8 room, uint256 q) internal returns (uint256 id) {
        vm.prank(alice);
        return rooms.openRound(v, room, q, type(uint256).max);
    }

    function buy(uint256 id, address user, uint8 room, uint256 q) internal {
        vm.prank(user);
        rooms.buyTickets(id, room, q, type(uint256).max);
    }
}
