// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { ClaimsTest } from "./ClaimsTest.sol";
import { RevenueFacet } from "../../src/facets/RevenueFacet.sol";

abstract contract RevenueTest is ClaimsTest {
    RevenueFacet internal revenue;

    function setUp() public virtual override {
        super.setUp();
        install(address(new RevenueFacet()), one(RevenueFacet.flushOperatorRevenue.selector));
        revenue = RevenueFacet(diamond);
    }
}
