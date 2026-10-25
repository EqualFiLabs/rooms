// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { LibOperatorFeeRouter } from "./LibOperatorFeeRouter.sol";
import { RoomsConfig, Round, RoundStatus } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";

library LibRoomsOpening {
    event RoundOpened(
        uint256 indexed roundId,
        uint64 indexed configVersion,
        uint64 indexed integrationVersion,
        uint64 openedAt,
        uint64 closesAt,
        uint256 inheritedPot,
        uint256 ticketSupply
    );

    /// @dev Internal reservation; caller must commit randomness and pay the first purchase atomically.
    function reserve(uint64 version) internal returns (uint256 id) {
        S.GameStorage storage g = S.gameStorage();
        if (S.governanceStorage().paused) revert Errors.ProtocolPaused();
        if (version == 0 || version > g.nextConfigVersion) revert Errors.ConfigNotFound(version);
        if (!g.configEnabled[version]) revert Errors.ConfigDisabled(version);
        RoomsConfig storage c = g.configs[version];
        if (!S.accountingStorage().assetApproved[c.paymentToken]) {
            revert Errors.AssetNotApproved(c.paymentToken);
        }
        if (g.activeRoundForConfig[version] != 0) {
            revert Errors.ConfigAlreadyActive(version, g.activeRoundForConfig[version]);
        }
        if (g.activeRoundCount >= g.maxActiveRounds) revert Errors.ActiveRoundLimitReached();
        uint64 integration = S.integrationStorage().currentVersion;
        if (integration == 0) revert Errors.IntegrationNotConfigured();
        if (c.operatorBps != 0) {
            LibOperatorFeeRouter.enforceReady(
                S.integrationStorage().integrations[integration].operatorFeeRouter, c.paymentToken
            );
        }
        id = ++g.nextRoundId;
        Round storage r = g.rounds[id];
        r.config = c;
        r.configVersion = version;
        r.integrationVersion = integration;
        r.openedAt = SafeCast.toUint64(block.timestamp);
        r.closesAt = SafeCast.toUint64(block.timestamp + c.salesDuration);
        r.effectiveClose = r.closesAt;
        r.status = RoundStatus.Open;
        g.activeRoundForConfig[version] = id;
        ++g.activeRoundCount;
        uint256 inherited = g.pendingRollover[version];
        if (inherited != 0) {
            g.pendingRollover[version] = 0;
            r.rolloverIn = inherited;
            S.accountingStorage().assets[c.paymentToken].pendingRolloverTotal -= inherited;
            S.accountingStorage().assets[c.paymentToken].activeRoundEscrow += inherited;
        }
        emit RoundOpened(
            id, version, integration, r.openedAt, r.closesAt, inherited, c.ticketSupply
        );
    }
}
