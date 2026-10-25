// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RevenueTest } from "./RevenueTest.sol";
import { RoomsViewFacet } from "../../src/facets/RoomsViewFacet.sol";

abstract contract ViewTest is RevenueTest {
    RoomsViewFacet internal views;

    function setUp() public virtual override {
        super.setUp();
        bytes4[] memory s = new bytes4[](20);
        s[0] = RoomsViewFacet.roomsConfig.selector;
        s[1] = RoomsViewFacet.integrationVersion.selector;
        s[2] = RoomsViewFacet.round.selector;
        s[3] = RoomsViewFacet.roundPhase.selector;
        s[4] = RoomsViewFacet.roomTicketCount.selector;
        s[5] = RoomsViewFacet.roomTicketCounts.selector;
        s[6] = RoomsViewFacet.userRoomTicketCount.selector;
        s[7] = RoomsViewFacet.prizeClaimed.selector;
        s[8] = RoomsViewFacet.claimablePrize.selector;
        s[9] = RoomsViewFacet.finalizerCredit.selector;
        s[10] = RoomsViewFacet.pendingOperatorRevenue.selector;
        s[11] = RoomsViewFacet.assetAccounting.selector;
        s[12] = RoomsViewFacet.assetBalanceAndAccounted.selector;
        s[13] = RoomsViewFacet.isAssetApproved.selector;
        s[14] = RoomsViewFacet.isKnownAsset.selector;
        s[15] = RoomsViewFacet.pendingRollover.selector;
        s[16] = RoomsViewFacet.activeRoundForConfig.selector;
        s[17] = RoomsViewFacet.maxActiveRounds.selector;
        s[18] = RoomsViewFacet.activeRoundCount.selector;
        s[19] = RoomsViewFacet.quotePurchase.selector;
        install(address(new RoomsViewFacet()), s);
        views = RoomsViewFacet(diamond);
    }
}
