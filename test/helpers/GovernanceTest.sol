// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RoomsTest } from "./RoomsTest.sol";
import { GovernanceFacet } from "../../src/facets/GovernanceFacet.sol";

abstract contract GovernanceTest is RoomsTest {
    GovernanceFacet internal gov;

    function setUp() public virtual override {
        super.setUp();
        bytes4[] memory s = new bytes4[](14);
        s[0] = GovernanceFacet.createRoomsConfig.selector;
        s[1] = GovernanceFacet.setRoomsConfigEnabled.selector;
        s[2] = GovernanceFacet.setAssetApproved.selector;
        s[3] = GovernanceFacet.setIntegrationConfig.selector;
        s[4] = GovernanceFacet.integrationConfig.selector;
        s[5] = GovernanceFacet.setMaxActiveRounds.selector;
        s[6] = GovernanceFacet.setTreasuryRecipient.selector;
        s[7] = GovernanceFacet.setGuardian.selector;
        s[8] = GovernanceFacet.setPaused.selector;
        s[9] = GovernanceFacet.paused.selector;
        s[10] = GovernanceFacet.guardian.selector;
        s[11] = GovernanceFacet.treasuryRecipient.selector;
        s[12] = GovernanceFacet.protocolFinalized.selector;
        s[13] = GovernanceFacet.finalizeProtocol.selector;
        install(address(new GovernanceFacet()), s);
        gov = GovernanceFacet(diamond);
    }
}
