# Rooms operation

An approved configuration defines one canonical ERC-20 asset, a base-unit ticket price, total supply across all rooms, sales duration of at least four seconds, randomness delay, optional per-purchase quantity limit, split, finalizer-tip rate and 2–24 rooms. Opening requires the first paid purchase. Each configuration has at most one unsettled round, and a global capacity limit bounds concurrent rounds. Configuration records are immutable; new records and integration endpoints receive new versions. Current approval controls new exposure, while historical liabilities remain payable.

Sales stop on the first exact supply fill or the original deadline. The round divides its original duration into four epochs: `floor(4 * elapsed / duration)`. Ticket unit price is the ceiling of base price times 1.00, 1.25, 1.50 or 1.75. Multiply this rounded unit by quantity. All tickets have equal prize weight. Splitting a purchase within one epoch does not reduce payment. Quotes can change before inclusion; supply can be consumed by another transaction. Supply cannot be partially filled, and `maxPayment` caps the entire charge.

Public occupancy lets a buyer compare conditional payout in each room. A late buyer can intentionally enter a populated room and reduce each existing ticket's conditional share of the winning pot. The late price premium charges more for that information advantage; it does not guarantee that dilution is unprofitable or eliminated. More tickets do not change the room's draw probability. A conditional preview assumes that room wins and the observed occupancy/payment state survives until the cutoff.

Opening commits the first Registry round strictly after the original close plus configured delay. The exact-fill purchase, strictly before the deadline, selects the first round strictly after its own timestamp plus delay in the same transaction; the original target remains visible. Each selected round must be uncached at commitment. There is no other retarget, cancellation, fallback beacon or timeout refund. Settlement uses only the selected future target, through a valid proof or its explicit cached-presence bit, including a zero randomness value. The application seed is `keccak256(abi.encode(randomness, chainId, diamond, roundId))`; its integer modulo room count selects a room. Cache provenance must follow the effective close. These checks depend on honest Registry/chain behavior and do not prove that a sequencer cannot know or manipulate ordering. A delayed beacon can leave escrow locked indefinitely.

Let G be new ticket receipts and R inherited rollover. Player allocation is `floor(G * potBps / 10000)`, Operator allocation is `floor(G * operatorBps / 10000)`, and gross treasury is the complement. The finalizer tip is a percentage of gross treasury, deducted only from treasury. Inherited R pays no new fees. Initial allocation is 50/20/30 before the treasury-funded tip. A zero-receipt successor does not exist because opening requires payment.

If the selected room is empty, its whole player pot becomes pending rollover for that configuration. Otherwise divide the player pot by winning-ticket count, credit the distributable multiple as prize liability, and send division dust to the same pending configuration pot. The next paid opening attaches its whole pending pot to escrow once. Pots do not expire or migrate. Repeated empty outcomes can accumulate inherited funds, while each new round's fresh receipts still fund its fees. Disabled configurations can retain inactive pots indefinitely.

A winning holder claims all of their winning-room tickets once, to a valid chosen receiver. Claims require a strictly earlier timestamp than settlement plus exactly 30 days. At or after that boundary, anyone can reclassify all remaining prizes to treasury once. No participant enumeration is needed. Expired but unprocessed prizes remain protected liabilities. Finalizer credits, Operator buckets and rollover have no player-claim expiry. Pause and asset removal do not stop settlement or exits and do not extend the claim deadline.

Each known asset has six disjoint categories: active escrow, player prize liability, pending rollover, finalizer liability, pending Operator revenue and treasury revenue. Escrow includes inherited amounts already attached to active rounds. Source pots, round prizes, finalizer credits and historical integration buckets reconcile to their aggregates. Only genuine balance above all six categories is absorbable surplus. Donations become treasury revenue after explicit absorption. Unsupported tokens cannot enter the known-token surplus path. Ordinary native sends revert; forced native value can only be delivered to the current treasury receiver.

Settlement allocates accounting and releases capacity without delivering tokens or calling the Router. Anyone may later flush an amount from a snapshotted Operator bucket to its original Router after readiness checks; allowance is exact for that call and cleared afterward. Treasury sends use the current stored treasury receiver. Failed token, receiver or Router delivery preserves the obligation for retry. Permissionless callers may perform maintenance but receive no arbitrary payout: only settlement earns the configured credit for its caller. That credit does not guarantee gas reimbursement.

Supported assets must be canonical, exact-transfer and non-rebasing, without aliases sharing a mutable balance. SafeERC20 handles false/reverting transfers but does not verify those asset-policy assumptions. Issuer freezes, upgrades or confiscation can delay delivery or defeat backing assumptions. Router and Registry remain external dependencies.

The external timelock controls selector changes until irreversible `finalizeProtocol`. It can install arbitrary code before then. Guardian can pause exposure, while only authority can unpause. Finalization fixes selectors and initialization but preserves configuration, integration, capacity, treasury and guardian governance. A finalized contract still depends on external assets, endpoints and chain behavior. There is no automatic finalization date.

## Direct calls

Use the compiled interfaces and candidate manifest to inspect selectors and runtime identity. Substitute only independently verified addresses and integer base-unit amounts. Commands below are read-only or encode calldata; they do not sign or broadcast.

```sh
cast call "$ROOMS" 'roomTicketCounts(uint256)(uint256[])' "$ROUND_ID" --rpc-url "$RPC_URL"
cast call "$ROOMS" 'quotePurchase(uint256,uint256)(uint8,uint16,uint256,uint256,uint256)' "$ROUND_ID" "$QUANTITY" --rpc-url "$RPC_URL"
cast call "$ROOMS" 'claimablePrize(uint256,address)(uint256)' "$ROUND_ID" "$PLAYER" --rpc-url "$RPC_URL"
cast calldata 'openRound(uint64,uint8,uint256,uint256)' "$CONFIG_VERSION" "$ROOM" "$QUANTITY" "$MAX_PAYMENT"
cast calldata 'buyTickets(uint256,uint8,uint256,uint256)' "$ROUND_ID" "$ROOM" "$QUANTITY" "$MAX_PAYMENT"
cast calldata 'settleRound(uint256,bytes)' "$ROUND_ID" "$SIGNATURE"
cast calldata 'claimPrize(uint256,address)' "$ROUND_ID" "$RECEIVER"
cast calldata 'expirePrize(uint256)' "$ROUND_ID"
cast calldata 'claimFinalizerTips(address,address)' "$ASSET" "$RECEIVER"
cast calldata 'flushOperatorRevenue(uint64,address,uint256)' "$INTEGRATION_VERSION" "$ASSET" "$AMOUNT"
cast calldata 'flushTreasury(address,uint256)' "$ASSET" "$AMOUNT"
```

A buyer must separately approve the Diamond for the supported token. No frontend or private backend is required. Obtain a valid selected-target signature or use an already cached selected beacon; an empty signature does not create randomness. A release operator must prepare and verify timelock schedule/execute calldata, candidate identities and complete inputs before any separately authorized activation.
