// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import {
    RoomsConfig,
    IntegrationConfig,
    Round,
    RoundPhase,
    AssetAccounting
} from "../shared/Types.sol";

interface IRoomsView {
    function roomsConfig(uint64 version) external view returns (RoomsConfig memory, bool);
    function integrationVersion(uint64 version) external view returns (IntegrationConfig memory);
    function round(uint256 id) external view returns (Round memory);
    function roundPhase(uint256 id) external view returns (RoundPhase);
    function roomTicketCount(uint256 id, uint8 room) external view returns (uint256);
    function roomTicketCounts(uint256 id) external view returns (uint256[] memory);
    function userRoomTicketCount(uint256 id, uint8 room, address user)
        external
        view
        returns (uint256);
    function prizeClaimed(uint256 id, address user) external view returns (bool);
    function claimablePrize(uint256 id, address user) external view returns (uint256);
    function finalizerCredit(address asset, address user) external view returns (uint256);
    function pendingOperatorRevenue(uint64 version, address asset) external view returns (uint256);
    function assetAccounting(address asset) external view returns (AssetAccounting memory);
    function assetBalanceAndAccounted(address asset) external view returns (uint256, uint256);
    function isAssetApproved(address asset) external view returns (bool);
    function isKnownAsset(address asset) external view returns (bool);
    function pendingRollover(uint64 version) external view returns (uint256);
    function activeRoundForConfig(uint64 version) external view returns (uint256);
    function maxActiveRounds() external view returns (uint16);
    function activeRoundCount() external view returns (uint256);
    function quotePurchase(uint256 id, uint256 quantity)
        external
        view
        returns (uint8, uint16, uint256, uint256, uint256);
    function previewRoomPayout(uint256 id, uint8 room, uint256 additionalTickets)
        external
        view
        returns (
            uint256 projectedPot,
            uint256 projectedRoomTickets,
            uint256 projectedPayoutPerTicket
        );
}
