// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

struct RoomsConfig {
    address paymentToken;
    uint96 baseTicketPrice;
    uint256 ticketSupply;
    uint32 salesDuration;
    uint32 randomnessDelay;
    uint32 maxTicketsPerPurchase;
    uint16 potBps;
    uint16 operatorBps;
    uint16 settlementTipBps;
    uint8 roomCount;
}

struct IntegrationConfig {
    address drandRegistry;
    address operatorFeeRouter;
}

enum RoundStatus {
    None,
    Open,
    SoldOut,
    Settled
}
enum RoundPhase {
    None,
    Open,
    Locked,
    SoldOut,
    Settled
}

struct Round {
    RoomsConfig config;
    uint64 configVersion;
    uint64 integrationVersion;
    uint64 openedAt;
    uint64 closesAt;
    uint64 soldOutAt;
    uint64 effectiveClose;
    uint64 settledAt;
    uint64 claimDeadline;
    uint64 deadlineDrandRound;
    uint64 drandRound;
    RoundStatus status;
    uint8 winningRoom;
    bool prizeExpired;
    uint256 totalTickets;
    uint256 receipts;
    uint256 rolloverIn;
    uint256 payoutPerTicket;
    uint256 prizeRemaining;
    bytes32 applicationSeed;
}

struct AssetAccounting {
    uint256 activeRoundEscrow;
    uint256 prizeLiability;
    uint256 pendingRolloverTotal;
    uint256 finalizerLiability;
    uint256 pendingOperatorRevenueTotal;
    uint256 treasuryAvailable;
}

/// @dev New-receipt allocations; inherited funds are excluded from all fees.
struct Allocations {
    uint256 pot;
    uint256 operatorRevenue;
    uint256 treasuryGross;
    uint256 finalizerTip;
    uint256 treasuryNet;
}
