// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { SettlementTest } from "./SettlementTest.sol";
import { ClaimsFacet } from "../../src/facets/ClaimsFacet.sol";

abstract contract ClaimsTest is SettlementTest {
    ClaimsFacet internal claims;

    function setUp() public virtual override {
        super.setUp();
        install(address(new ClaimsFacet()), one(ClaimsFacet.claimPrize.selector));
        claims = ClaimsFacet(diamond);
        install(address(new ClaimsFacet()), one(ClaimsFacet.claimFinalizerTips.selector));
        install(address(new ClaimsFacet()), one(ClaimsFacet.expirePrize.selector));
    }

    function fundedPrize() internal returns (uint256 id) {
        id = open(1, 0, 30);
        buy(id, bob, 0, 20);
        buy(id, alice, 1, 50);
        finish(id, 0);
    }
}
