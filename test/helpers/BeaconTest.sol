// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { LifecycleTest } from "./LifecycleTest.sol";
import { Round } from "./RoomsTest.sol";

abstract contract BeaconTest is LifecycleTest {
    /// @dev Deterministic outcome generation is a local fixture, never a live target policy.
    function cacheForRoom(uint256 id, uint8 room) internal {
        Round memory r = inspect.roundState(id);
        uint256 timestamp = uint256(registry.roundTime(r.drandRound)) + 1;
        if (timestamp > block.timestamp) vm.warp(timestamp);
        bytes32 randomness;
        for (uint256 i;; ++i) {
            randomness = bytes32(i);
            if (
                uint256(keccak256(abi.encode(randomness, block.chainid, diamond, id)))
                        % r.config.roomCount == room
            ) break;
        }
        registry.cache(r.drandRound, randomness);
    }
}
