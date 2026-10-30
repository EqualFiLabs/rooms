// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { RoomsConfig } from "./Types.sol";

interface Events {
    event RoomsConfigCreated(uint64 indexed version, address indexed asset, RoomsConfig config);
    event RoomsConfigEnabled(uint64 indexed version, bool enabled);
    event AssetApprovalUpdated(address indexed asset, bool approved);
    event IntegrationConfigUpdated(uint64 indexed version, address registry, address router);
    event MaxActiveRoundsUpdated(uint16 previousLimit, uint16 limit);
    event GuardianUpdated(address previousGuardian, address guardian);
    event TreasuryRecipientUpdated(address previousRecipient, address recipient);
    event PauseStateUpdated(bool paused);
    event ProtocolFinalized();
}
