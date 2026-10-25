// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { Script } from "forge-std/Script.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { RoomsInit } from "../src/initializers/RoomsInit.sol";
import { IDiamondCut } from "../src/interfaces/IDiamondCut.sol";
import { FacetCut, FacetCutAction } from "../src/shared/DiamondTypes.sol";
import { DiamondLoupeFacet } from "../src/facets/DiamondLoupeFacet.sol";
import { GovernanceFacet } from "../src/facets/GovernanceFacet.sol";
import { RoomsFacet } from "../src/facets/RoomsFacet.sol";
import { SettlementFacet } from "../src/facets/SettlementFacet.sol";
import { ClaimsFacet } from "../src/facets/ClaimsFacet.sol";
import { RevenueFacet } from "../src/facets/RevenueFacet.sol";
import { RoomsViewFacet } from "../src/facets/RoomsViewFacet.sol";

/// @notice Local assembly only. Does not start a broadcaster or load signing material.
/// @dev Constructor authority is the supplied external timelock from the first deployment.
contract DeployRooms is Script {
    struct Assembly {
        address diamond;
        address cutFacet;
        address initializer;
        address[7] facets;
        bytes activationCalldata;
    }

    function prepare(RoomsInit.InitParams memory p, uint256 expectedDelay)
        external
        returns (Assembly memory a)
    {
        require(block.chainid == 46_630, "rehearsal chain");
        require(p.authority.code.length != 0 && expectedDelay != 0, "external timelock");
        require(TimelockController(payable(p.authority)).getMinDelay() == expectedDelay, "delay");
        require(p.roomsConfigs.length != 0 && p.maxActiveRounds != 0, "launch inputs");
        for (uint256 i; i < p.roomsConfigs.length; ++i) {
            require(
                p.roomsConfigs[i].potBps == 5000 && p.roomsConfigs[i].operatorBps == 2000,
                "initial split"
            );
        }
        a.cutFacet = deployCode("DiamondCutFacet.sol:DiamondCutFacet");
        a.initializer = deployCode("RoomsInit.sol:RoomsInit");
        a.facets[0] = deployCode("DiamondLoupeFacet.sol:DiamondLoupeFacet");
        a.facets[1] = deployCode("GovernanceFacet.sol:GovernanceFacet");
        a.facets[2] = deployCode("RoomsFacet.sol:RoomsFacet");
        a.facets[3] = deployCode("SettlementFacet.sol:SettlementFacet");
        a.facets[4] = deployCode("ClaimsFacet.sol:ClaimsFacet");
        a.facets[5] = deployCode("RevenueFacet.sol:RevenueFacet");
        a.facets[6] = deployCode("RoomsViewFacet.sol:RoomsViewFacet");
        a.diamond = deployCode("RoomsDiamond.sol:RoomsDiamond", abi.encode(p.authority, a.cutFacet));
        a.activationCalldata = abi.encodeCall(
            IDiamondCut.diamondCut,
            (applicationCuts(a.facets), a.initializer, abi.encodeCall(RoomsInit.initialize, (p)))
        );
    }

    function applicationCuts(address[7] memory facets)
        public
        pure
        returns (FacetCut[] memory cuts)
    {
        cuts = new FacetCut[](7);
        bytes4[] memory selectors;
        selectors = new bytes4[](4);
        selectors[0] = DiamondLoupeFacet.facetAddress.selector;
        selectors[1] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[2] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[3] = DiamondLoupeFacet.facets.selector;
        cuts[0] = FacetCut(facets[0], FacetCutAction.Add, selectors);
        selectors = new bytes4[](14);
        selectors[0] = GovernanceFacet.createRoomsConfig.selector;
        selectors[1] = GovernanceFacet.finalizeProtocol.selector;
        selectors[2] = GovernanceFacet.guardian.selector;
        selectors[3] = GovernanceFacet.integrationConfig.selector;
        selectors[4] = GovernanceFacet.paused.selector;
        selectors[5] = GovernanceFacet.protocolFinalized.selector;
        selectors[6] = GovernanceFacet.setAssetApproved.selector;
        selectors[7] = GovernanceFacet.setGuardian.selector;
        selectors[8] = GovernanceFacet.setIntegrationConfig.selector;
        selectors[9] = GovernanceFacet.setMaxActiveRounds.selector;
        selectors[10] = GovernanceFacet.setPaused.selector;
        selectors[11] = GovernanceFacet.setRoomsConfigEnabled.selector;
        selectors[12] = GovernanceFacet.setTreasuryRecipient.selector;
        selectors[13] = GovernanceFacet.treasuryRecipient.selector;
        cuts[1] = FacetCut(facets[1], FacetCutAction.Add, selectors);
        selectors = new bytes4[](2);
        selectors[0] = RoomsFacet.buyTickets.selector;
        selectors[1] = RoomsFacet.openRound.selector;
        cuts[2] = FacetCut(facets[2], FacetCutAction.Add, selectors);
        selectors = new bytes4[](1);
        selectors[0] = SettlementFacet.settleRound.selector;
        cuts[3] = FacetCut(facets[3], FacetCutAction.Add, selectors);
        selectors = new bytes4[](3);
        selectors[0] = ClaimsFacet.claimFinalizerTips.selector;
        selectors[1] = ClaimsFacet.claimPrize.selector;
        selectors[2] = ClaimsFacet.expirePrize.selector;
        cuts[4] = FacetCut(facets[4], FacetCutAction.Add, selectors);
        selectors = new bytes4[](5);
        selectors[0] = RevenueFacet.absorbTokenSurplus.selector;
        selectors[1] = RevenueFacet.availableTokenSurplus.selector;
        selectors[2] = RevenueFacet.flushNativeSurplus.selector;
        selectors[3] = RevenueFacet.flushOperatorRevenue.selector;
        selectors[4] = RevenueFacet.flushTreasury.selector;
        cuts[5] = FacetCut(facets[5], FacetCutAction.Add, selectors);
        selectors = new bytes4[](21);
        selectors[0] = RoomsViewFacet.activeRoundCount.selector;
        selectors[1] = RoomsViewFacet.activeRoundForConfig.selector;
        selectors[2] = RoomsViewFacet.assetAccounting.selector;
        selectors[3] = RoomsViewFacet.assetBalanceAndAccounted.selector;
        selectors[4] = RoomsViewFacet.claimablePrize.selector;
        selectors[5] = RoomsViewFacet.finalizerCredit.selector;
        selectors[6] = RoomsViewFacet.integrationVersion.selector;
        selectors[7] = RoomsViewFacet.isAssetApproved.selector;
        selectors[8] = RoomsViewFacet.isKnownAsset.selector;
        selectors[9] = RoomsViewFacet.maxActiveRounds.selector;
        selectors[10] = RoomsViewFacet.pendingOperatorRevenue.selector;
        selectors[11] = RoomsViewFacet.pendingRollover.selector;
        selectors[12] = RoomsViewFacet.previewRoomPayout.selector;
        selectors[13] = RoomsViewFacet.prizeClaimed.selector;
        selectors[14] = RoomsViewFacet.quotePurchase.selector;
        selectors[15] = RoomsViewFacet.roomTicketCount.selector;
        selectors[16] = RoomsViewFacet.roomTicketCounts.selector;
        selectors[17] = RoomsViewFacet.roomsConfig.selector;
        selectors[18] = RoomsViewFacet.round.selector;
        selectors[19] = RoomsViewFacet.roundPhase.selector;
        selectors[20] = RoomsViewFacet.userRoomTicketCount.selector;
        cuts[6] = FacetCut(facets[6], FacetCutAction.Add, selectors);
    }
}
