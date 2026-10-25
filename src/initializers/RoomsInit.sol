// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibRoomsConfig } from "../libraries/LibRoomsConfig.sol";
import { LibReentrancy } from "../libraries/LibReentrancy.sol";
import { RoomsConfig, IntegrationConfig } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";
import { Events } from "../shared/Events.sol";

/// @notice Delegatecall initializer; installed atomically with the application's first cut.
contract RoomsInit is Events {
    struct InitParams {
        address authority;
        address guardian;
        address treasuryRecipient;
        uint16 maxActiveRounds;
        IntegrationConfig integration;
        address[] approvedAssets;
        RoomsConfig[] roomsConfigs;
    }

    function initialize(InitParams calldata p) external {
        LibDiamond.enforceAuthority();
        if (p.authority != LibDiamond.authority()) {
            revert Errors.AuthorityMismatch(LibDiamond.authority(), p.authority);
        }
        if (
            p.guardian == address(0) || p.treasuryRecipient == address(0)
                || p.treasuryRecipient == address(this)
        ) revert Errors.InvalidAddress();
        if (p.roomsConfigs.length == 0) revert Errors.EmptyRoomsConfigurations();
        LibRoomsConfig.validate(p.integration);
        LibReentrancy.initialize();
        S.IntegrationStorage storage i = S.integrationStorage();
        i.currentVersion = 1;
        i.integrations[1] = p.integration;
        emit IntegrationConfigUpdated(
            1, p.integration.drandRegistry, p.integration.operatorFeeRouter
        );
        S.GovernanceStorage storage gov = S.governanceStorage();
        gov.guardian = p.guardian;
        gov.treasuryRecipient = p.treasuryRecipient;
        emit GuardianUpdated(address(0), p.guardian);
        emit TreasuryRecipientUpdated(address(0), p.treasuryRecipient);
        S.GameStorage storage g = S.gameStorage();
        g.maxActiveRounds = p.maxActiveRounds;
        emit MaxActiveRoundsUpdated(0, p.maxActiveRounds);
        for (uint256 n; n < p.approvedAssets.length; ++n) {
            address asset = p.approvedAssets[n];
            LibRoomsConfig.validateContract(asset);
            S.accountingStorage().assetApproved[asset] = true;
            S.accountingStorage().knownAsset[asset] = true;
            emit AssetApprovalUpdated(asset, true);
        }
        for (uint256 n; n < p.roomsConfigs.length; ++n) {
            RoomsConfig calldata c = p.roomsConfigs[n];
            LibRoomsConfig.validate(c);
            uint64 v = ++g.nextConfigVersion;
            g.configs[v] = c;
            g.configEnabled[v] = true;
            emit RoomsConfigCreated(v, c.paymentToken, c);
            emit RoomsConfigEnabled(v, true);
        }
    }
}
