// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RoomsTest } from "./RoomsTest.sol";
import { GovernanceFacet } from "../../src/facets/GovernanceFacet.sol";

abstract contract GovernanceTest is RoomsTest {
    GovernanceFacet internal gov;

    function setUp() public virtual override {
        super.setUp();
        bytes4[] memory s = new bytes4[](3);
        s[0] = GovernanceFacet.createRoomsConfig.selector;
        s[1] = GovernanceFacet.setRoomsConfigEnabled.selector;
        s[2] = GovernanceFacet.setAssetApproved.selector;
        install(address(new GovernanceFacet()), s);
        gov = GovernanceFacet(diamond);
    }
}
