// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { BeaconTest } from "./BeaconTest.sol";
import { SettlementFacet } from "../../src/facets/SettlementFacet.sol";
import { AssetAccounting } from "./RoomsTest.sol";

abstract contract SettlementTest is BeaconTest {
    SettlementFacet internal settlement;

    function setUp() public virtual override {
        super.setUp();
        install(address(new SettlementFacet()), one(SettlementFacet.settleRound.selector));
        settlement = SettlementFacet(diamond);
    }

    function finish(uint256 id, uint8 room) internal {
        cacheForRoom(id, room);
        assertEq(settlement.settleRound(id, ""), room);
    }

    function assertBacked(address asset) internal view {
        AssetAccounting memory a = inspect.accounting(asset);
        uint256 sum = a.activeRoundEscrow + a.prizeLiability + a.pendingRolloverTotal
            + a.finalizerLiability + a.pendingOperatorRevenueTotal + a.treasuryAvailable;
        assertEq(sum, tokenBalance(asset));
    }

    function tokenBalance(address asset) internal view returns (uint256) {
        (bool ok, bytes memory data) =
            asset.staticcall(abi.encodeWithSignature("balanceOf(address)", diamond));
        require(ok);
        return abi.decode(data, (uint256));
    }
}
