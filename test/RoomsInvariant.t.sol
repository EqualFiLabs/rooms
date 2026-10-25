// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { Test } from "forge-std/Test.sol";
import { ViewTest } from "./helpers/ViewTest.sol";
import { TestToken } from "./helpers/RoomsTest.sol";
import {
    Round,
    RoundStatus,
    RoomsConfig,
    IntegrationConfig,
    AssetAccounting
} from "../src/shared/Types.sol";

/// @dev Chosen-room Registry fixture, real Diamond dispatch and supported-token transfers.
contract RoomsHandler is ViewTest {
    struct Model {
        uint64 version;
        uint64 integration;
        uint64 opened;
        uint64 closes;
        uint64 originalTarget;
        uint64 selectedTarget;
        bytes32 terms;
        uint256 receipts;
        uint256 total;
        uint256 inherited;
        uint256 prize;
        uint256 paid;
        uint256 expiredAmount;
        uint8 winner;
        bool settled;
        bool sold;
        bool expired;
    }
    TestToken public second;
    uint256 public last;
    uint64 public integration = 1;
    mapping(uint256 => Model) internal model;
    mapping(uint256 => mapping(uint8 => uint256)) internal occupancy;
    mapping(uint256 => mapping(address => mapping(uint8 => uint256))) internal holding;
    mapping(uint256 => mapping(address => bool)) internal consumed;
    mapping(uint64 => uint256) internal pending;
    mapping(address => uint256) internal deposits;
    mapping(address => uint256) internal donations;
    mapping(address => uint256) internal absorbed;
    mapping(address => uint256) internal delivered;
    mapping(address => uint256) internal tipsPaid;
    mapping(address => uint256) internal treasuryPaid;
    mapping(uint64 => mapping(address => uint256)) internal operatorPaid;
    uint256 public transitions;

    function setUp() public override {
        super.setUp();
        second = new TestToken();
        gov.setAssetApproved(address(second), true);
        second.mint(alice, 1e30);
        second.mint(bob, 1e30);
        vm.prank(alice);
        second.approve(diamond, type(uint256).max);
        vm.prank(bob);
        second.approve(diamond, type(uint256).max);
        gov.setRoomsConfigEnabled(1, false);
        gov.setMaxActiveRounds(4);
        RoomsConfig memory c = fixture();
        c.baseTicketPrice = 3;
        c.ticketSupply = 20;
        c.salesDuration = 12;
        for (uint256 i; i < 3; ++i) {
            c.paymentToken = i == 1 ? address(second) : address(token);
            uint64 v = gov.createRoomsConfig(c);
            gov.setRoomsConfigEnabled(v, true);
        }
    }

    function asset(uint64 v) internal view returns (address) {
        return v == 3 ? address(second) : address(token);
    }

    function actOpen(uint8 raw, uint8 roomRaw, uint8 quantityRaw) external {
        uint64 v = 2 + uint64(raw % 3);
        address a = asset(v);
        if (gov.paused() || !views.isAssetApproved(a) || views.activeRoundForConfig(v) != 0) {
            return;
        }
        uint256 q = 1 + uint256(quantityRaw) % 20;
        uint8 room = roomRaw % 2;
        uint256 id = open(v, room, q);
        last = id;
        Round memory r = views.round(id);
        Model storage m = model[id];
        m.version = v;
        m.integration = integration;
        m.opened = uint64(block.timestamp);
        m.closes = uint64(block.timestamp + 12);
        m.originalTarget = registry.firstRoundAfter(block.timestamp + 12 + 30);
        m.selectedTarget = q == 20
            ? registry.firstRoundAfter(block.timestamp + 30)
            : m.originalTarget;
        m.terms = keccak256(abi.encode(r.config));
        m.inherited = pending[v];
        pending[v] = 0;
        m.receipts = q * 3;
        m.total = q;
        m.sold = q == 20;
        occupancy[id][room] = q;
        holding[id][alice][room] = q;
        deposits[a] += q * 3;
        ++transitions;
    }

    function actBuy(uint256 raw, uint8 roomRaw, uint8 quantityRaw, bool who) external {
        if (last == 0) return;
        uint256 id = 1 + raw % last;
        Model storage m = model[id];
        if (
            m.settled || m.sold || block.timestamp >= m.closes || gov.paused()
                || !views.isAssetApproved(asset(m.version))
        ) return;
        uint256 q = 1 + uint256(quantityRaw) % (20 - m.total);
        uint8 room = roomRaw % 2;
        address user = who ? alice : bob;
        uint256 epoch = (block.timestamp - m.opened) * 4 / 12;
        uint256 unit = (3 * (10_000 + epoch * 2500) + 9999) / 10_000;
        if (q == 20 - m.total && registry.hasSig(registry.firstRoundAfter(block.timestamp + 30))) {
            return;
        }
        uint256 payment = q * unit;
        vm.prank(user);
        rooms.buyTickets(id, room, q, payment);
        m.receipts += payment;
        m.total += q;
        occupancy[id][room] += q;
        holding[id][user][room] += q;
        deposits[asset(m.version)] += payment;
        if (m.total == 20) {
            m.sold = true;
            m.selectedTarget = registry.firstRoundAfter(block.timestamp + 30);
        }
        ++transitions;
    }

    function actTime(uint32 step) external {
        vm.warp(block.timestamp + uint256(step) % 40 days);
    }

    function actSettle(uint256 raw, uint8 outcome) external {
        if (last == 0) return;
        uint256 id = 1 + raw % last;
        Model storage m = model[id];
        if (m.settled) return;
        uint8 room = outcome % 2;
        if (registry.hasSig(m.selectedTarget)) {
            settlement.settleRound(id, bytes(""));
            room = views.round(id).winningRoom;
        } else {
            finish(id, room);
        }
        m.settled = true;
        m.winner = room;
        uint256 pot = m.inherited + m.receipts / 2;
        uint256 winners = occupancy[id][room];
        m.prize = winners == 0 ? 0 : pot / winners * winners;
        pending[m.version] += pot - m.prize;
        ++transitions;
    }

    function actClaimOrExpire(uint256 raw, bool who, bool expire) external {
        if (last == 0) return;
        uint256 id = 1 + raw % last;
        Model storage m = model[id];
        if (!m.settled) return;
        Round memory r = views.round(id);
        address a = asset(m.version);
        if (expire) {
            if (m.expired || occupancy[id][m.winner] == 0) return;
            if (block.timestamp < r.claimDeadline) vm.warp(r.claimDeadline);
            uint256 amount = claims.expirePrize(id);
            assertEq(amount, m.prize - m.paid);
            m.expired = true;
            m.expiredAmount = amount;
        } else {
            address user = who ? alice : bob;
            uint256 amount = holding[id][user][m.winner] * r.payoutPerTicket;
            if (amount == 0 || consumed[id][user] || block.timestamp >= r.claimDeadline) return;
            vm.prank(user);
            assertEq(claims.claimPrize(id, user), amount);
            consumed[id][user] = true;
            m.paid += amount;
            delivered[a] += amount;
        }
        ++transitions;
    }

    function actDonate(uint96 raw, bool other, bool absorb) external {
        TestToken t = other ? second : token;
        address a = address(t);
        uint256 amount = uint256(raw) % 1000 + 1;
        t.mint(alice, amount);
        vm.prank(alice);
        t.transfer(diamond, amount);
        donations[a] += amount;
        if (absorb) {
            uint256 value = revenue.absorbTokenSurplus(a);
            absorbed[a] += value;
        }
        ++transitions;
    }

    function actDeliver(uint8 raw, bool other) external {
        address a = other ? address(second) : address(token);
        uint8 kind = raw % 3;
        if (kind == 0) {
            uint256 value = views.finalizerCredit(a, address(this));
            if (value == 0) return;
            assertEq(claims.claimFinalizerTips(a, alice), value);
            tipsPaid[a] += value;
            delivered[a] += value;
        } else if (kind == 1) {
            uint256 value = views.assetAccounting(a).treasuryAvailable;
            if (value == 0) return;
            assertEq(revenue.flushTreasury(a, value), value);
            treasuryPaid[a] += value;
            delivered[a] += value;
        } else {
            uint64 v = 1 + uint64(raw) % integration;
            uint256 value = views.pendingOperatorRevenue(v, a);
            if (value == 0) return;
            assertEq(revenue.flushOperatorRevenue(v, a, value), value);
            operatorPaid[v][a] += value;
            delivered[a] += value;
        }
        ++transitions;
    }

    function actAdmission(bool pause, bool approval, bool newIntegration) external {
        gov.setPaused(pause);
        gov.setAssetApproved(address(token), approval);
        if (newIntegration && integration < 5) {
            gov.setIntegrationConfig(IntegrationConfig(address(registry), address(router)));
            ++integration;
        }
    }

    function assertModel() external view {
        uint256 active;
        for (uint256 id = 1; id <= last; ++id) {
            Model storage m = model[id];
            Round memory r = views.round(id);
            assertEq(r.receipts, m.receipts);
            assertEq(r.totalTickets, m.total);
            assertLe(m.total, 20);
            assertEq(r.rolloverIn, m.inherited);
            assertEq(keccak256(abi.encode(r.config)), m.terms);
            assertEq(r.openedAt, m.opened);
            assertEq(r.closesAt, m.closes);
            assertEq(r.deadlineDrandRound, m.originalTarget);
            assertEq(r.drandRound, m.selectedTarget);
            assertEq(r.integrationVersion, m.integration);
            assertEq(
                uint8(r.status),
                uint8(
                    m.settled
                        ? RoundStatus.Settled
                        : m.sold ? RoundStatus.SoldOut : RoundStatus.Open
                )
            );
            if (m.settled) {
                assertEq(r.prizeRemaining, m.prize - m.paid - m.expiredAmount);
                assertEq(r.prizeExpired, m.expired);
                assertEq(views.prizeClaimed(id, alice), consumed[id][alice]);
                assertEq(views.prizeClaimed(id, bob), consumed[id][bob]);
            } else {
                ++active;
                assertEq(views.activeRoundForConfig(m.version), id);
            }
            for (uint8 room; room < 2; ++room) {
                assertEq(views.roomTicketCount(id, room), occupancy[id][room]);
                assertEq(
                    views.userRoomTicketCount(id, room, alice)
                        + views.userRoomTicketCount(id, room, bob),
                    occupancy[id][room]
                );
            }
        }
        assertEq(views.activeRoundCount(), active);
        for (uint64 v = 2; v <= 4; ++v) {
            assertEq(views.pendingRollover(v), pending[v]);
        }
        reconcile(address(token));
        reconcile(address(second));
    }

    function reconcile(address a) internal view {
        AssetAccounting memory expected;
        uint256[] memory buckets = new uint256[](uint256(integration) + 1);
        for (uint256 id = 1; id <= last; ++id) {
            Model storage m = model[id];
            if (asset(m.version) != a) continue;
            if (!m.settled) {
                expected.activeRoundEscrow += m.receipts + m.inherited;
                continue;
            }
            expected.prizeLiability += m.prize - m.paid - m.expiredAmount;
            uint256 pot = m.receipts / 2;
            uint256 op = m.receipts * 2000 / 10_000;
            uint256 tg = m.receipts - pot - op;
            uint256 tip = tg * 500 / 10_000;
            expected.finalizerLiability += tip;
            expected.treasuryAvailable += tg - tip + m.expiredAmount;
            buckets[m.integration] += op;
        }
        expected.finalizerLiability -= tipsPaid[a];
        expected.treasuryAvailable += absorbed[a];
        expected.treasuryAvailable -= treasuryPaid[a];
        for (uint64 v = 1; v <= integration; ++v) {
            buckets[v] -= operatorPaid[v][a];
            assertEq(views.pendingOperatorRevenue(v, a), buckets[v]);
            expected.pendingOperatorRevenueTotal += buckets[v];
        }
        for (uint64 v = 2; v <= 4; ++v) {
            if (asset(v) == a) expected.pendingRolloverTotal += pending[v];
        }
        assertEq(abi.encode(views.assetAccounting(a)), abi.encode(expected));
        assertEq(views.finalizerCredit(a, address(this)), expected.finalizerLiability);
        (uint256 balance, uint256 accounted) = views.assetBalanceAndAccounted(a);
        assertGe(balance, accounted);
        assertEq(balance, deposits[a] + donations[a] - delivered[a]);
        assertEq(balance - accounted, donations[a] - absorbed[a]);
    }
}

contract RoomsInvariantTest is Test {
    RoomsHandler internal handler;

    function setUp() public {
        handler = new RoomsHandler();
        handler.setUp();
        targetContract(address(handler));
        bytes4[] memory s = new bytes4[](8);
        s[0] = handler.actOpen.selector;
        s[1] = handler.actBuy.selector;
        s[2] = handler.actTime.selector;
        s[3] = handler.actSettle.selector;
        s[4] = handler.actClaimOrExpire.selector;
        s[5] = handler.actDonate.selector;
        s[6] = handler.actDeliver.selector;
        s[7] = handler.actAdmission.selector;
        targetSelector(FuzzSelector(address(handler), s));
    }

    function invariantSourceLedgersAndSolvency() public view {
        handler.assertModel();
    }

    function testReachableLifecycleWitness() public {
        handler.actOpen(0, 0, 2);
        handler.actBuy(0, 1, 3, true);
        handler.actSettle(0, 0);
        handler.actClaimOrExpire(0, true, false);
        handler.actDonate(7, false, true);
        handler.actDeliver(1, false);
        handler.assertModel();
        assertGt(handler.transitions(), 4);
    }
}
