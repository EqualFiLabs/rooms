// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { LifecycleTest } from "./helpers/LifecycleTest.sol";
import { SettlementComponents } from "./helpers/SettlementComponents.sol";
import { Round, Errors } from "./helpers/RoomsTest.sol";

contract RoomsSettlementComponentsTest is LifecycleTest {
    SettlementComponents internal h;

    function setUp() public override {
        super.setUp();
        install(address(new SettlementComponents()), one(SettlementComponents.acquire.selector));
        h = SettlementComponents(diamond);
    }

    function testCacheReuseZeroRandomnessAndDomainSeparation() public {
        uint256 id = open(1, 0, 100);
        Round memory r = inspect.roundState(id);
        vm.warp(block.timestamp + 1);
        registry.cache(r.drandRound, bytes32(0));
        (bytes32 seed, uint8 room) = h.acquire(id, hex"bad0");
        assertEq(seed, keccak256(abi.encode(bytes32(0), block.chainid, diamond, id)));
        assertEq(room, uint256(seed) % 2);
        registry.setBad(false, false, true);
        (bytes32 again,) = h.acquire(id, hex"ff");
        assertEq(again, seed);
        vm.chainId(block.chainid + 1);
        (again,) = h.acquire(id, "");
        assertNotEq(again, seed);
    }

    function testOnlySelectedTargetNoOriginalFallback() public {
        uint256 id = open(1, 0, 100);
        Round memory r = inspect.roundState(id);
        vm.warp(block.timestamp + 1);
        registry.cache(r.deadlineDrandRound, bytes32(uint256(7)));
        registry.setBad(false, false, true);
        vm.expectRevert("bad proof");
        h.acquire(id, hex"1234");
        registry.cache(r.drandRound, bytes32(uint256(9)));
        h.acquire(id, "");
    }

    function testDeadlineEligibilityAndInvalidProofRollback() public {
        uint256 id = open(1, 0, 1);
        Round memory r = inspect.roundState(id);
        vm.expectRevert(abi.encodeWithSelector(Errors.RoundNotReady.selector, id));
        h.acquire(id, hex"01");
        vm.warp(r.closesAt);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.RandomnessPredatesClose.selector, r.drandRound, r.closesAt, r.closesAt
            )
        );
        h.acquire(id, hex"01");
        assertFalse(registry.hasSig(r.drandRound));
        vm.warp(uint256(r.closesAt) + 1);
        registry.setBad(false, false, true);
        vm.expectRevert("bad proof");
        h.acquire(id, hex"01");
        assertFalse(registry.hasSig(r.drandRound));
        registry.setBad(false, false, false);
        (bytes32 seed,) = h.acquire(id, hex"01");
        assertEq(seed, keccak256(abi.encode(keccak256(hex"01"), block.chainid, diamond, id)));
    }

    function testCachedTooEarlyRemainsUnusable() public {
        uint256 id = open(1, 0, 1);
        Round memory r = inspect.roundState(id);
        registry.cache(r.drandRound, bytes32(0));
        vm.warp(uint256(r.closesAt) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.RandomnessPredatesClose.selector, r.drandRound, r.openedAt, r.closesAt
            )
        );
        h.acquire(id, "");
    }
}
