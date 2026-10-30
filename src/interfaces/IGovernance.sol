// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { RoomsConfig, IntegrationConfig } from "../shared/Types.sol";
import { Events } from "../shared/Events.sol";

interface IGovernance is Events {
    function createRoomsConfig(RoomsConfig calldata config) external returns (uint64 version);
    function setRoomsConfigEnabled(uint64 version, bool enabled) external;
    function setAssetApproved(address asset, bool approved) external;
    function setIntegrationConfig(IntegrationConfig calldata config) external;
    function integrationConfig()
        external
        view
        returns (IntegrationConfig memory config, uint64 version);
    function setMaxActiveRounds(uint16 limit) external;
    function setTreasuryRecipient(address recipient) external;
    function setGuardian(address guardian) external;
    function setPaused(bool paused) external;
    function paused() external view returns (bool);
    function guardian() external view returns (address);
    function treasuryRecipient() external view returns (address);
    function protocolFinalized() external view returns (bool);
    function finalizeProtocol() external;
}
