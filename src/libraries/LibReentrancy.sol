// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { LibRoomsStorage } from "./LibRoomsStorage.sol";
import { Errors } from "../shared/Errors.sol";

library LibReentrancy {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    function initialize() internal {
        LibRoomsStorage.ReentrancyStorage storage rs = LibRoomsStorage.reentrancyStorage();
        if (rs.status != 0) revert Errors.AlreadyInitialized();
        rs.status = NOT_ENTERED;
    }

    function enter() internal {
        LibRoomsStorage.ReentrancyStorage storage rs = LibRoomsStorage.reentrancyStorage();
        if (rs.status != NOT_ENTERED) revert Errors.Reentrancy();
        rs.status = ENTERED;
    }

    function exit() internal {
        LibRoomsStorage.reentrancyStorage().status = NOT_ENTERED;
    }

    function entered() internal view returns (bool) {
        return LibRoomsStorage.reentrancyStorage().status == ENTERED;
    }
}
