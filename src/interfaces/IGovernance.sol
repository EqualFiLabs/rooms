// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { RoomsConfig } from "../shared/Types.sol";
import { Events } from "../shared/Events.sol";

interface IGovernance is Events {
    function createRoomsConfig(RoomsConfig calldata config) external returns (uint64 version);
    function setRoomsConfigEnabled(uint64 version, bool enabled) external;
}
