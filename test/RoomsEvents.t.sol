// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ViewTest } from "./helpers/ViewTest.sol";
import { Vm } from "forge-std/Vm.sol";
import { Allocations, AssetAccounting } from "../src/shared/Types.sol";

contract RoomsEventsTest is ViewTest {
    function testReceiptsAndSettlementCanBeReconstructedFromEconomicLogs() public {
        vm.recordLogs();
        uint256 id = open(1, 0, 30);
        vm.warp(block.timestamp + 100);
        buy(id, bob, 0, 20);
        buy(id, alice, 1, 50);
        finish(id, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 gross;
        uint256 count;
        Allocations memory a;
        uint256 allocated;
        uint256 inherited;
        uint256 rollover;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != diamond) continue;
            bytes32 topic = logs[i].topics[0];
            if (
                topic
                    == keccak256(
                        "TicketsPurchased(uint256,address,uint8,uint256,uint8,uint256,uint256,uint256)"
                    )
            ) {
                (uint256 q,, uint256 unit, uint256 pay, uint256 left) =
                    abi.decode(logs[i].data, (uint256, uint8, uint256, uint256, uint256));
                assertEq(pay, q * unit);
                gross += pay;
                count += q;
                assertEq(left, 100 - count);
            } else if (
                topic
                    == keccak256(
                        "RoundAllocated(uint256,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))"
                    )
            ) {
                (allocated, inherited, a) =
                    abi.decode(logs[i].data, (uint256, uint256, Allocations));
            } else if (topic == keccak256("RolloverCredited(uint256,uint64,address,uint256)")) {
                rollover += abi.decode(logs[i].data, (uint256));
            }
        }
        assertEq(gross, allocated);
        assertEq(gross, 117.5 ether);
        assertEq(gross, a.pot + a.operatorRevenue + a.finalizerTip + a.treasuryNet);
        AssetAccounting memory book = views.assetAccounting(address(token));
        assertEq(book.prizeLiability + rollover, inherited + a.pot);
        assertEq(book.pendingOperatorRevenueTotal, a.operatorRevenue);
        assertEq(book.finalizerLiability, a.finalizerTip);
        assertEq(book.treasuryAvailable, a.treasuryNet);
        assertEq(count, views.round(id).totalTickets);
    }
}
