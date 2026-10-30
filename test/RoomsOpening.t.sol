// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { GovernanceTest } from "./helpers/GovernanceTest.sol";
import {
    Round,
    RoomsConfig,
    IntegrationConfig,
    MockRegistry,
    MockRouter,
    Errors
} from "./helpers/RoomsTest.sol";
import { LibRoomsStorage as S } from "../src/libraries/LibRoomsStorage.sol";
import { LibRoomsOpening } from "../src/libraries/LibRoomsOpening.sol";
import { LibRoomsPurchase } from "../src/libraries/LibRoomsPurchase.sol";
import { Guarded } from "../src/shared/Guarded.sol";

contract OpeningHarness is Guarded {
    function paidReserve(uint64 v, uint8 room, uint256 q, uint256 max)
        external
        nonReentrant
        returns (uint256 id)
    {
        id = LibRoomsOpening.reserve(v);
        uint256 payment = LibRoomsPurchase.record(id, room, q, max);
        LibRoomsPurchase.collect(id, payment);
    }

    function seedPot(uint64 v, uint256 amount) external {
        S.gameStorage().pendingRollover[v] += amount;
        address asset = S.gameStorage().configs[v].paymentToken;
        S.accountingStorage().assets[asset].pendingRolloverTotal += amount;
    }
}

contract RoomsOpeningTest is GovernanceTest {
    OpeningHarness internal h;

    function setUp() public override {
        super.setUp();
        bytes4[] memory s = new bytes4[](2);
        s[0] = OpeningHarness.paidReserve.selector;
        s[1] = OpeningHarness.seedPot.selector;
        install(address(new OpeningHarness()), s);
        h = OpeningHarness(diamond);
    }

    function testPaidOpeningAndConcurrentSnapshotIsolation() public {
        uint64 second = gov.createRoomsConfig(fixture());
        gov.setRoomsConfigEnabled(second, true);
        vm.prank(alice);
        uint256 id = h.paidReserve(1, 0, 2, 2 ether);
        gov.setIntegrationConfig(
            IntegrationConfig(address(new MockRegistry()), address(new MockRouter()))
        );
        vm.prank(bob);
        uint256 next = h.paidReserve(second, 1, 1, 1 ether);
        Round memory r = inspect.roundState(id);
        assertEq(r.integrationVersion, 1);
        assertEq(inspect.roundState(next).integrationVersion, 2);
        assertEq(inspect.activeFor(1), id);
        (, uint256 active,,,) = inspect.state();
        assertEq(active, 2);
        vm.expectRevert(abi.encodeWithSelector(Errors.ConfigAlreadyActive.selector, uint64(1), id));
        h.paidReserve(1, 0, 1, 1 ether);
        gov.setMaxActiveRounds(0);
        uint64 third = gov.createRoomsConfig(fixture());
        gov.setRoomsConfigEnabled(third, true);
        vm.expectRevert(Errors.ActiveRoundLimitReached.selector);
        h.paidReserve(third, 0, 1, 1 ether);
    }

    function testInheritedPotAttachmentAndFailedFirstPurchaseRollback() public {
        token.mint(diamond, 9 ether);
        h.seedPot(1, 9 ether);
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        vm.prank(alice);
        h.paidReserve(1, 0, 1, 1 ether);
        assertEq(inspect.rollover(1), 9 ether);
        assertEq(inspect.activeFor(1), 0);
        (, uint256 active,,,) = inspect.state();
        assertEq(active, 0);
        assertEq(inspect.accounting(address(token)).pendingRolloverTotal, 9 ether);
        token.setFail(false);
        vm.prank(alice);
        uint256 id = h.paidReserve(1, 0, 1, 1 ether);
        assertEq(id, 1);
        assertEq(inspect.roundState(id).rolloverIn, 9 ether);
        assertEq(inspect.rollover(1), 0);
        assertEq(inspect.accounting(address(token)).activeRoundEscrow, 10 ether);
    }

    function testReadinessAndZeroOperatorShare() public {
        router.setReady(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.OperatorRouterUnavailable.selector, address(router), address(token)
            )
        );
        h.paidReserve(1, 0, 1, 1 ether);
        RoomsConfig memory c = fixture();
        c.operatorBps = 0;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        vm.prank(alice);
        h.paidReserve(v, 0, 1, 1 ether);
    }
}
