// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { AssetAccounting, IntegrationConfig, RoomsConfig, Round } from "../shared/Types.sol";

library LibRoomsStorage {
    bytes32 internal constant GAME_STORAGE_SLOT = keccak256("equalfi.rooms.storage.game.v1");
    bytes32 internal constant INTEGRATION_STORAGE_SLOT =
        keccak256("equalfi.rooms.storage.integration.v1");
    bytes32 internal constant ACCOUNTING_STORAGE_SLOT =
        keccak256("equalfi.rooms.storage.accounting.v1");
    bytes32 internal constant GOVERNANCE_STORAGE_SLOT =
        keccak256("equalfi.rooms.storage.governance.v1");
    bytes32 internal constant REENTRANCY_STORAGE_SLOT =
        keccak256("equalfi.rooms.storage.reentrancy.v1");

    struct GameStorage {
        uint64 nextConfigVersion;
        uint16 maxActiveRounds;
        uint256 nextRoundId;
        uint256 activeRoundCount;
        mapping(uint64 version => RoomsConfig config) configs;
        mapping(uint64 version => bool enabled) configEnabled;
        mapping(uint256 roundId => Round round) rounds;
        mapping(uint64 configVersion => uint256 roundId) activeRoundForConfig;
        mapping(uint64 configVersion => uint256 amount) pendingRollover;
        mapping(uint256 roundId => mapping(uint8 room => uint256 count)) roomTickets;
        mapping(
            uint256 roundId => mapping(uint8 room => mapping(address user => uint256 count))
        ) userRoomTickets;
        mapping(uint256 roundId => mapping(address user => bool claimed)) prizeClaimed;
    }

    struct IntegrationStorage {
        uint64 currentVersion;
        mapping(uint64 version => IntegrationConfig config) integrations;
    }

    struct AccountingStorage {
        mapping(address asset => AssetAccounting accounting) assets;
        mapping(uint64 integrationVersion => mapping(address asset => uint256 amount))
            pendingOperatorRevenue;
        mapping(address asset => mapping(address finalizer => uint256 amount)) finalizerCredits;
        mapping(address asset => bool known) knownAsset;
        mapping(address asset => bool approved) assetApproved;
    }

    struct GovernanceStorage {
        address guardian;
        address treasuryRecipient;
        bool paused;
    }

    struct ReentrancyStorage {
        uint256 status;
    }

    function gameStorage() internal pure returns (GameStorage storage s) {
        bytes32 slot = GAME_STORAGE_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }

    function integrationStorage() internal pure returns (IntegrationStorage storage s) {
        bytes32 slot = INTEGRATION_STORAGE_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }

    function accountingStorage() internal pure returns (AccountingStorage storage s) {
        bytes32 slot = ACCOUNTING_STORAGE_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }

    function governanceStorage() internal pure returns (GovernanceStorage storage s) {
        bytes32 slot = GOVERNANCE_STORAGE_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }

    function reentrancyStorage() internal pure returns (ReentrancyStorage storage s) {
        bytes32 slot = REENTRANCY_STORAGE_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }
}
