// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @title EqualFi drand Registry interface
/// @notice Stable consumer surface for verified drand Quicknet beacons.
interface IEqualFiDrandRegistry {
    /// @notice Emitted when a Quicknet round is first verified and permanently cached.
    event QuicknetSignaturePosted(
        uint64 indexed round,
        address indexed poster,
        bytes32 indexed randomness,
        bytes submittedSignature
    );

    /// @notice Returns the first Quicknet round scheduled strictly after `timestamp`.
    function firstRoundAfter(uint256 timestamp) external pure returns (uint64 round);

    /// @notice Returns the scheduled Unix timestamp for `round`.
    function roundTime(uint64 round) external pure returns (uint64 timestamp);

    /// @notice Returns whether `round` has verified and permanently cached randomness.
    function hasSig(uint64 round) external view returns (bool);

    /// @notice Returns the canonical randomness cached for `round`, or zero if absent.
    function randomnessOf(uint64 round) external view returns (bytes32 randomness);

    /// @notice Returns the timestamp at which `round` was first cached, or zero if absent.
    function postedAt(uint64 round) external view returns (uint64 timestamp);

    /// @notice Verifies and caches a Quicknet signature for `round` permissionlessly.
    /// @return newlyStored True only when this call performs the first successful write.
    function postSig(uint64 round, bytes calldata signature) external returns (bool newlyStored);
}
