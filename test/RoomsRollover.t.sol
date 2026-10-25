// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { BeaconTest } from "./helpers/BeaconTest.sol";
import { Round, RoomsConfig, TestToken } from "./helpers/RoomsTest.sol";
import { LibRoomsStorage as S } from "../src/libraries/LibRoomsStorage.sol";
import { LibRoomsSettlement } from "../src/libraries/LibRoomsSettlement.sol";
import { LibRoomsOutcome } from "../src/libraries/LibRoomsOutcome.sol";
import { Guarded } from "../src/shared/Guarded.sol";

contract EmptyOutcomeHarness is Guarded {
    function finishEmpty(uint256 id, bytes calldata sig) external nonReentrant {
        (bytes32 seed, uint8 room) = LibRoomsSettlement.acquire(id, sig);
        require(S.gameStorage().roomTickets[id][room] == 0, "populated fixture");
        uint256 pot = LibRoomsSettlement.common(id, seed, room);
        LibRoomsOutcome.rollover(id, pot);
    }
}

contract RoomsRolloverTest is BeaconTest {
    EmptyOutcomeHarness internal h;

    function setUp() public override {
        super.setUp();
        install(address(new EmptyOutcomeHarness()), one(EmptyOutcomeHarness.finishEmpty.selector));
        h = EmptyOutcomeHarness(diamond);
    }

    function testRepeatedEmptyPotAttachesExactlyOnceAndFeesUseNewReceipts() public {
        for (uint256 n; n < 3; ++n) {
            uint256 id = open(1, 0, 10);
            Round memory r = inspect.roundState(id);
            assertEq(r.rolloverIn, n * 5 ether);
            assertEq(inspect.rollover(1), 0);
            assertEq(inspect.accounting(address(token)).pendingRolloverTotal, 0);
            cacheForRoom(id, 1);
            h.finishEmpty(id, "");
            assertEq(inspect.rollover(1), (n + 1) * 5 ether);
            assertEq(inspect.roundState(id).claimDeadline, 0);
            assertEq(inspect.roundState(id).prizeRemaining, 0);
            assertEq(inspect.bucket(1, address(token)), (n + 1) * 2 ether);
            assertEq(inspect.accounting(address(token)).activeRoundEscrow, 0);
        }
        uint256 next = open(1, 0, 1);
        assertEq(inspect.roundState(next).rolloverIn, 15 ether);
        assertEq(inspect.rollover(1), 0);
        assertEq(inspect.accounting(address(token)).activeRoundEscrow, 16 ether);
    }

    function testConfigurationAndAssetPotsRemainSeparate() public {
        uint64 second = gov.createRoomsConfig(fixture());
        gov.setRoomsConfigEnabled(second, true);
        uint256 first = open(1, 0, 10);
        vm.warp(block.timestamp + 3);
        uint256 other = open(second, 0, 20);
        cacheForRoom(first, 1);
        h.finishEmpty(first, "");
        cacheForRoom(other, 1);
        h.finishEmpty(other, "");
        assertEq(inspect.rollover(1), 5 ether);
        assertEq(inspect.rollover(second), 10 ether);
        TestToken another = new TestToken();
        gov.setAssetApproved(address(another), true);
        another.mint(alice, 100 ether);
        vm.prank(alice);
        another.approve(diamond, type(uint256).max);
        RoomsConfig memory c = fixture();
        c.paymentToken = address(another);
        uint64 third = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(third, true);
        uint256 id = open(third, 0, 6);
        cacheForRoom(id, 1);
        h.finishEmpty(id, "");
        assertEq(inspect.rollover(third), 3 ether);
        assertEq(inspect.accounting(address(another)).pendingRolloverTotal, 3 ether);
        assertEq(inspect.accounting(address(token)).pendingRolloverTotal, 15 ether);
        assertEq(inspect.rollover(1), 5 ether);
    }
}
