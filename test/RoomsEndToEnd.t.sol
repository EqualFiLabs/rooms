// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ViewTest } from "./helpers/ViewTest.sol";
import { Round, RoomsConfig, IntegrationConfig } from "../src/shared/Types.sol";
import { EqualFiDrandRegistry } from "./generated/registry/EqualFiDrandRegistry.sol";
import { OperatorFeeRouter } from "../lib/operator-fee-router/src/OperatorFeeRouter.sol";
import {
    MockVault,
    MockAuthority,
    MockOperatorCollection,
    MockActivationRegistry
} from "../lib/operator-fee-router/test/mocks/MockOperatorSystem.sol";

/// @dev Real Registry and Router code; collection, authority and payment asset are local fixtures.
contract RoomsEndToEndTest is ViewTest {
    EqualFiDrandRegistry internal realRegistry;
    OperatorFeeRouter internal realRouter;
    address internal routerAuthority;
    uint64 internal constant VECTOR = 20_791_007;
    bytes internal constant SIGNATURE =
        hex"8d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac5";

    function setUp() public override {
        super.setUp();
        realRegistry = new EqualFiDrandRegistry();
        MockVault vault = new MockVault();
        routerAuthority = address(new MockAuthority());
        MockOperatorCollection collection = new MockOperatorCollection(address(vault));
        MockActivationRegistry activation = new MockActivationRegistry(address(collection));
        collection.bindActivationRegistry(address(activation));
        collection.setOwner(1, bob);
        realRouter = new OperatorFeeRouter(
            address(collection), address(activation), address(vault), routerAuthority
        );
        for (uint256 i; i < 56; ++i) {
            realRouter.bootstrapOperators(100);
        }
        realRouter.finalizeBootstrap();
        vm.prank(routerAuthority);
        realRouter.registerRewardAsset(address(token));
        gov.setIntegrationConfig(IntegrationConfig(address(realRegistry), address(realRouter)));
    }

    function prepare(uint256 offset) internal returns (uint256 id) {
        RoomsConfig memory c = fixture();
        c.salesDuration = 8;
        c.randomnessDelay = 0;
        uint64 v = gov.createRoomsConfig(c);
        gov.setRoomsConfigEnabled(v, true);
        // Both the deadline and an early cutoff select the fixed published Quicknet vector.
        vm.warp(realRegistry.roundTime(VECTOR) - offset);
        id = open(v, 0, 30);
    }

    function proveAndSettle(uint256 id, bool preCache) internal returns (Round memory r) {
        vm.warp(realRegistry.roundTime(VECTOR) + 1);
        if (preCache) realRegistry.postSig(VECTOR, SIGNATURE);
        settlement.settleRound(id, preCache ? bytes("") : SIGNATURE);
        r = views.round(id);
        assertEq(r.drandRound, VECTOR);
        assertEq(
            r.applicationSeed,
            keccak256(abi.encode(realRegistry.randomnessOf(VECTOR), block.chainid, diamond, id))
        );
        assertEq(r.winningRoom, uint256(r.applicationSeed) % r.config.roomCount);
        assertBacked(address(token));
    }

    function testRealVectorMixedEpochSelloutAndRouterClaim() public {
        uint256 id = prepare(10);
        uint64 original = views.round(id).deadlineDrandRound;
        vm.warp(block.timestamp + 2);
        buy(id, bob, 1, 20);
        vm.warp(block.timestamp + 5);
        buy(id, alice, 0, 50);
        assertEq(views.round(id).deadlineDrandRound, original);
        Round memory r = proveAndSettle(id, false);
        assertEq(r.receipts, 142.5 ether);
        uint256 owed = views.pendingOperatorRevenue(2, address(token));
        // Router failure leaves the historical bucket intact and retryable.
        vm.prank(routerAuthority);
        realRouter.setRewardAssetEnabled(address(token), false);
        vm.expectRevert();
        revenue.flushOperatorRevenue(2, address(token), owed);
        assertEq(views.pendingOperatorRevenue(2, address(token)), owed);
        vm.prank(routerAuthority);
        realRouter.setRewardAssetEnabled(address(token), true);
        revenue.flushOperatorRevenue(2, address(token), owed);
        assertEq(token.allowance(diamond, address(realRouter)), 0);
        vm.prank(bob);
        assertEq(realRouter.claimOperatorRewards(1, address(token), bob), owed);
        gov.setPaused(true);
        gov.setAssetApproved(address(token), false);
        if (views.claimablePrize(id, alice) != 0) {
            vm.prank(alice);
            claims.claimPrize(id, alice);
        }
        vm.warp(r.claimDeadline);
        claims.expirePrize(id);
        claims.claimFinalizerTips(address(token), treasury);
        revenue.flushTreasury(
            address(token), views.assetAccounting(address(token)).treasuryAvailable
        );
        assertBacked(address(token));
    }

    function testRealVectorDeadlineCacheReuseAndContinuingOperation() public {
        uint256 id = prepare(10);
        uint64 target = views.round(id).drandRound;
        gov.finalizeProtocol();
        Round memory r = proveAndSettle(id, true);
        assertEq(r.drandRound, target);
        assertEq(r.receipts, 30 ether);
        // New integrations and configurations remain operational after cut finalization.
        gov.setIntegrationConfig(IntegrationConfig(address(registry), address(realRouter)));
        uint256 pending = views.pendingRollover(r.configVersion);
        uint256 next = open(r.configVersion, 1, 1);
        assertEq(views.round(next).rolloverIn, pending);
        assertEq(views.round(next).integrationVersion, 3);
        finish(next, 1);
        assertBacked(address(token));
    }
}
