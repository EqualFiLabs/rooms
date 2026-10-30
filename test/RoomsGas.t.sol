// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RoomsEndToEndTest } from "./RoomsEndToEnd.t.sol";
import { TestToken } from "./helpers/RoomsTest.sol";
import { RoomsConfig, IntegrationConfig } from "../src/shared/Types.sol";

contract GasSixDecimalToken is TestToken {
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract RoomsGasTest is RoomsEndToEndTest {
    function testMeasuredLifecycleAcrossRoomCountsAndAssetUnits() public {
        GasSixDecimalToken six = new GasSixDecimalToken();
        gov.setAssetApproved(address(six), true);
        six.mint(alice, 1e20);
        six.mint(bob, 1e20);
        vm.prank(alice);
        six.approve(diamond, type(uint256).max);
        vm.prank(bob);
        six.approve(diamond, type(uint256).max);
        vm.prank(routerAuthority);
        realRouter.registerRewardAsset(address(six));
        gov.setIntegrationConfig(IntegrationConfig(address(registry), address(realRouter)));
        uint8[3] memory counts = [uint8(2), 8, 24];
        for (uint256 t; t < 2; ++t) {
            for (uint256 n; n < 3; ++n) {
                address a = t == 0 ? address(token) : address(six);
                RoomsConfig memory c = fixture();
                c.paymentToken = a;
                c.baseTicketPrice = t == 0 ? uint96(1 ether) : uint96(1e6);
                c.roomCount = counts[n];
                uint64 v = gov.createRoomsConfig(c);
                gov.setRoomsConfigEnabled(v, true);
                uint256 id = open(v, 0, 30);
                string memory label = string.concat(
                    vm.toString(counts[n]), " rooms / ", t == 0 ? "18 decimals / " : "6 decimals / "
                );
                vm.prank(bob);
                uint256 start = gasleft();
                rooms.buyTickets(id, 0, 20, type(uint256).max);
                emit log_named_uint(string.concat(label, "purchase"), start - gasleft());
                cacheForRoom(id, 0);
                start = gasleft();
                settlement.settleRound(id, bytes(""));
                emit log_named_uint(string.concat(label, "settlement"), start - gasleft());
                vm.prank(alice);
                start = gasleft();
                claims.claimPrize(id, alice);
                emit log_named_uint(string.concat(label, "claim"), start - gasleft());
                vm.warp(views.round(id).claimDeadline);
                start = gasleft();
                claims.expirePrize(id);
                emit log_named_uint(string.concat(label, "expiry"), start - gasleft());
                uint256 amount = views.pendingOperatorRevenue(3, a);
                start = gasleft();
                revenue.flushOperatorRevenue(3, a, amount);
                emit log_named_uint(string.concat(label, "Router contribution"), start - gasleft());
                assertBacked(a);
            }
        }
    }
}
