# Requirements Document

## Introduction

Rooms is a standalone EqualFi Labs onchain game. Players buy tickets in a chosen room at prices that increase across four time epochs: 1.00x, 1.25x, 1.50x, and 1.75x the base ticket price. Every ticket has equal prize entitlement, and room selection is independent of occupancy. Sales close on sellout or at the time limit, whichever comes first. A committed future drand Quicknet beacon selects a room, whose tickets share the player pot. An empty winning room carries that pot into the next round of the same configuration. Rooms supports concurrent configurations, approved ERC-20 assets, and 2–24 rooms per configuration. It reuses Fiddy's Diamond infrastructure and operating patterns, but owns independent custody, accounting, settlement, claims, and governance state. This is the accepted implementation specification. Implementation and feature-branch publication are authorized; live deployment, signing, broadcasting, and finalization remain outside this delivery.

The requested specification package consists of this document, [design.md](design.md), and [tasks.md](tasks.md), directly in the repository root. Requirement identifiers below are stable references; `8.3` means acceptance criterion 3 of Requirement 8.

Implementation inputs and external-authority policy are recorded in [configuration](docs/configuration.md); exact source pins and notices are in [provenance](docs/provenance.md). Production values remain unset. The implemented compiler is Solidity 0.8.33, Osaka, optimizer 200 runs, without global via-IR. [Protocol operation](docs/protocol.md), [acceptance evidence](docs/acceptance.md), and [handoff](docs/handoff.md) accompany the cumulative implementation. Target-chain execution remains prepared but unexecuted.

### Reference baseline and review status

- Fiddy: [`EqualFiLabs/fiddy`](https://github.com/EqualFiLabs/fiddy/tree/795425ef6a8830278b56b9052aa2271e92930eb3), merged `main` including PR #22.
- Registry: [`EqualFiLabs/drand-registry`](https://github.com/EqualFiLabs/drand-registry/tree/118a94d2e447055d1a47d1a13488e887aaa4a822), merged `main` including the local BLS helper implementation.
- The 50% player / 20% Operator / 30% treasury split is the initial economic configuration, not an immutable restriction on future configurations.
- Accepted settlement rule: the configurable settlement-tip percentage is a percentage of the round's gross treasury allocation, not gross entries or the inherited pot. It is funded exclusively from treasury. Requirements and design use this definition consistently.
- Accepted rounding rule: divide the player pot once into a per-ticket amount; carry the indivisible remainder into the next round's pot. This preserves exact wallet-splitting neutrality.
- Base ticket prices, ticket supplies, sales durations, randomness delays, tip percentages, addresses, and timelock parameters are deployment/configuration inputs. The four epoch price multipliers are fixed protocol terms. This package does not invent launch values or approve a deployment.
- The player claim period is fixed at 30 days after settlement. Finalizer credits and pending Operator revenue are not player prize claims and are not subject to that expiry.

## Glossary

- **Diamond:** Rooms' single custody address and selector-dispatch entry point, with Fiddy-derived facets and namespaced storage.
- **Authority:** The external timelock/governance executor configured as the Diamond authority.
- **Guardian:** A role allowed to pause new exposure, but not unpause or move funds.
- **Approved asset:** A canonical ERC-20 address currently permitted for new Rooms entries. Only exact-transfer, non-rebasing assets are admitted operationally; support for other behavior is out of scope.
- **Known asset:** An address previously approved and retained permanently for historical accounting and safe surplus reconciliation, even when new-entry approval is removed.
- **Configuration version:** An immutable set of economic terms, including payment asset, room count, base ticket price, total ticket supply, sales duration, allocation percentages, randomness delay, and settlement-tip percentage.
- **Integration version:** An immutable pair of Registry and OperatorFeeRouter addresses, selected and snapshotted at opening.
- **Round:** One paid sales window for a configuration. Each configuration has at most one nonterminal round.
- **Room:** An integer choice in `[0, roomCount)`. A frontend may display these as rooms 1 through `roomCount`.
- **Ticket:** A nontransferable counted entry, not an individually identified token or NFT.
- **Epoch:** One of four consecutive quarters of the original sales duration, determined by execution timestamp. E1–E4 apply 1.00x/1.25x/1.50x/1.75x to price only, never prize weight.
- **Sellout:** Sale of the configuration's full ticket supply across all rooms; the last purchase closes sales atomically before the deadline.
- **Effective close:** The sellout timestamp for a sold-out round, otherwise its original sales deadline. This is the cutoff used for settlement freshness.
- **Gross entries:** Payment-token principal received for a round's tickets; excludes rollover and direct donations.
- **Player pot:** The player allocation of new gross entries plus that round's inherited rollover.
- **Pending rollover:** A configuration's player funds waiting to be attached to its next round; never treasury surplus.
- **Settlement:** The one-shot transition recording the winning room and reclassifying escrow into liabilities, without asset delivery.
- **Player prize liability:** Settled, distributable prize not yet claimed or reclassified after the claim deadline.
- **Settlement reward:** A token-denominated credit assigned to the successful finalizer, funded from the round's treasury allocation.
- **Surplus:** Asset balance above all recorded obligations; direct donations create surplus, not tickets or jackpot entitlement.
- **Claim deadline:** `settledAt + 30 days`; player claims require a timestamp strictly before this deadline.

## Requirements

### Requirement 1: Standalone Diamond and custody isolation

**User Story:** As a participant, I want Rooms to hold only Rooms obligations, so that unrelated games cannot consume its backing.

#### Acceptance Criteria

1. THE Rooms implementation SHALL reuse Fiddy's Diamond dispatch, cut, loupe, authority, initialization, reentrancy, and irreversible-cut-finalization patterns rather than introduce an unrelated proxy design.
2. THE Rooms Diamond SHALL own independent balances, namespaced game/accounting/governance state, round identifiers, and claims.
3. THE implementation SHALL NOT introduce shared custody with Fiddy, a generic gaming vault, a generic game registry, per-round custody proxies, or a shared gaming accounting protocol.
4. THE Rooms implementation SHALL NOT modify Fiddy or make Fiddy depend on Rooms.
5. WHEN a facet operates through delegatecall, THE implementation SHALL preserve the Diamond as the custody address and the application-domain address used for randomness.
6. THE source and documentation SHALL distinguish reused Diamond infrastructure from Rooms-specific application logic and preserve applicable upstream license notices.

### Requirement 2: Immutable configuration versions and configurable economics

**User Story:** As governance, I want to offer different Rooms configurations without changing a round after players enter.

#### Acceptance Criteria

1. THE authority SHALL be able to create immutable, monotonically numbered configuration versions and independently enable or disable future openings for each version.
2. A configuration SHALL specify an approved payment asset, positive base ticket price, positive total ticket supply across all rooms, room count from 2 through 24 inclusive, sales duration of at least four seconds, randomness delay, player allocation BPS, Operator allocation BPS, settlement-tip BPS, and an optional per-purchase quantity limit. The minimum duration SHALL permit all four epochs to have representable timestamps.
3. THE initial launch configuration SHALL use 5,000 player BPS and 2,000 Operator BPS of gross entries; the complementary gross treasury share SHALL be 3,000 BPS.
4. THE configuration validator SHALL require a positive player allocation, a strictly positive complementary treasury allocation, nonnegative Operator allocation, and settlement-tip BPS in `[0, 10_000)` so treasury retains revenue on every funded round under the allocation rules.
5. WHEN a round opens, THE round SHALL snapshot its configuration and integration versions; subsequent governance changes SHALL NOT alter its base price, epoch pricing rules, ticket supply, room count, allocations, tip, deadline, or randomness schedule. Only the atomic sellout transition in Requirement 6.3 MAY replace the selected deadline beacon.
6. THE implementation SHALL allow arbitrary integer room counts within 2–24 and SHALL NOT require powers of two.
7. THE implementation SHALL close sales on sellout or at the original deadline, whichever comes first; it SHALL NOT impose a fixed daily cadence or 24-hour maximum sales duration. Ticket supply SHALL count actual tickets, not revenue or price-weighted units, and SHALL NOT be divided into per-room quotas.
8. THE player claim period SHALL remain fixed at 30 days; ordinary configuration governance SHALL NOT shorten or extend an existing or future round's claim period.

### Requirement 3: Approved ERC-20 assets and admission controls

**User Story:** As governance, I want to control supported assets without stranding liabilities when an asset is removed from new play.

#### Acceptance Criteria

1. THE authority SHALL be able to approve or remove an ERC-20 address for new entries; approval SHALL require a nonzero contract address other than the Rooms Diamond.
2. WHEN a configuration is created, a round opens, or tickets are bought, THE implementation SHALL require the payment asset to be currently approved.
3. WHEN approval is removed, THE implementation SHALL block new openings and ticket purchases for that asset, including purchases into an existing round, without cancelling that round.
4. THE implementation SHALL retain historical known-asset status and SHALL NOT gate settlement, player claims, prize expiry, finalizer claims, Operator delivery, treasury delivery, or surplus reconciliation on current approval.
5. THE implementation SHALL use SafeERC20-compatible calls, CEI, and reentrancy protection, but SHALL NOT add fee-on-transfer accommodation, rebasing support, decimal normalization, or per-transfer sender/receiver balance-delta checks.
6. THE asset-admission policy SHALL exclude fee-on-transfer, sender-fee, rebasing, and shared-ledger-alias assets; solvency guarantees SHALL explicitly assume approved assets continue their supported behavior.
7. THE implementation SHALL account in token base units without swaps or conversions between assets.
8. Removing approval SHALL NOT permit an authority to erase accounting, confiscate prizes, move rollover to treasury, or redirect pending Operator revenue.

### Requirement 4: Permissionless per-configuration round lifecycle

**User Story:** As a player, I want to open or join a configured round without waiting for an EqualFi operator.

#### Acceptance Criteria

1. WHEN an enabled configuration has no nonterminal round and capacity is available, any account SHALL be able to open its next round with a positive first ticket purchase.
2. THE round deadline SHALL equal its opening timestamp plus its snapshotted sales duration; opening SHALL atomically record the first purchase and randomness schedule or revert completely.
3. THE implementation SHALL enforce at most one nonterminal round per configuration version and a governance-configurable global nonterminal-round limit; a zero global limit SHALL block openings.
4. THE implementation SHALL permit configurations using the same or different assets to run concurrently; global round IDs SHALL NOT impose cross-configuration settlement order.
5. WHEN a round settles, THE implementation SHALL release its configuration slot and global capacity immediately, independently of claims, expiry, treasury delivery, or Router delivery.
6. THE round state SHALL progress from nonexistent to open, optionally to sold out, and then to settled; a settled round SHALL never reopen. The final ticket purchase SHALL close a sold-out round atomically. A passed deadline SHALL stop an unsold round's sales without requiring a separate close transaction. Neither close path SHALL release active capacity before settlement.
7. Disabling a configuration SHALL prevent future openings only; it SHALL NOT stop purchases in its already-open round unless pause or asset removal separately stops those purchases.

### Requirement 5: Ticket purchase and room occupancy

**User Story:** As a player, I want to select rooms and buy counted tickets with transparent occupancy and no address-based economic advantage.

#### Acceptance Criteria

1. A purchase SHALL identify a round, one valid room, a positive quantity, and a caller-selected maximum payment. For `elapsed = block.timestamp - openedAt` and `duration = salesDuration`, THE implementation SHALL select zero-based epoch `floor(4 * elapsed / duration)` while sales are open, apply multiplier BPS `[10_000, 12_500, 15_000, 17_500]`, and charge `quantity * ceil(baseTicketPrice * multiplierBps / 10_000)`. Rounding SHALL occur once per ticket price, not once per purchase total; a payment exceeding the caller's maximum SHALL revert atomically.
2. THE implementation SHALL record total round tickets, total tickets per room, and tickets per user per room without individual ticket IDs, winner lists, or cumulative ticket ranges.
3. A player SHALL be able to make repeated purchases and hold tickets in multiple rooms; THE contract SHALL NOT support transferring tickets or moving paid tickets between rooms.
4. IF a per-purchase limit is configured, THE implementation SHALL enforce it per transaction, not per wallet or round; zero SHALL mean no additional per-purchase limit.
5. Ticket recording SHALL be constant-time with respect to quantity, historical purchases, and winner count; checked arithmetic SHALL reject quantities whose amounts or counters are unrepresentable. A quantity exceeding remaining supply SHALL revert completely without partial filling or payment; a quantity exactly filling supply SHALL trigger sellout in the same transaction, including a first purchase that fills the round.
6. Direct token transfers SHALL NOT create tickets, increment round receipts, or change player prize calculations.
7. THE economic entitlement of a fixed ticket holding SHALL NOT improve by splitting it among wallets or purchases. Every ticket SHALL have equal prize weight regardless of purchase epoch or price paid; splitting an otherwise identical purchase within one epoch SHALL NOT reduce its total payment through rounding.

### Requirement 6: Future randomness commitment and sellout-or-deadline cutoff

**User Story:** As a player, I want sales to stop before the chosen beacon is available under the documented chain assumptions.

#### Acceptance Criteria

1. WHEN a round opens, THE implementation SHALL calculate `boundary = closesAt + randomnessDelay` and commit `registry.firstRoundAfter(boundary)` using its snapshotted Registry. THE implementation SHALL retain this original deadline target for public reconstruction.
2. At each allowed commitment, THE implementation SHALL require a nonzero target, `registry.roundTime(target) > boundary`, and absence of that target in the Registry cache. Failure SHALL revert the complete opening or sellout purchase, respectively.
3. Only a purchase that exactly fills remaining supply strictly before `closesAt` SHALL replace the selected deadline target once, atomically, with `registry.firstRoundAfter(soldOutAt + randomnessDelay)` from the same snapshotted Registry. THE resulting sellout target SHALL be final even if identical to the original target. An unsold round SHALL retain its deadline target. THE implementation SHALL NOT reschedule at deadline, on epoch changes or pause, after governance changes, or when a finalizer arrives late, and SHALL NOT choose between targets at settlement.
4. Ticket purchases SHALL require an open, not-sold-out round, available supply, and `block.timestamp < closesAt`; a transaction at the exact deadline SHALL be rejected even if it would fill the last tickets. Epochs SHALL follow the original duration and SHALL NOT accelerate, reset, or reprice existing tickets on sellout.
5. THE implementation SHALL NOT require a final purchase or an operator transaction to establish the deadline commitment.
6. THE specification SHALL distinguish L2 timestamp/cache-ordering guarantees from real-time beacon secrecy and SHALL disclose the Robinhood honest-sequencer and timestamp-progression assumptions.
7. THE implementation SHALL NOT claim that cache absence or a short configurable delay independently defeats malicious-sequencer timestamp manipulation.

### Requirement 7: Permissionless accounting-only settlement and no refunds

**User Story:** As a participant or finalizer, I want any eligible round to settle from its exact beacon without recipient cooperation.

#### Acceptance Criteria

1. Any account SHALL be able to settle an unsettled round after sellout or at/after its original deadline, provided its selected committed beacon satisfies the settlement checks. An unsold round, including one with only one ticket, SHALL settle from actual receipts without a refund or minimum-sales requirement.
2. IF the committed beacon is absent, THE settlement function SHALL accept proof bytes and call Registry `postSig`; IF already cached, it SHALL reuse the cached value without requiring or interpreting proof bytes.
3. THE implementation SHALL require the selected committed beacon to be cached and `registry.postedAt(target) > effectiveClose` before deriving an application seed, where effective close is the recorded sellout timestamp for a sold-out round and otherwise `closesAt`.
4. THE application seed SHALL be `keccak256(abi.encode(registry.randomnessOf(target), block.chainid, address(RoomsDiamond), roundId))`; the winning room SHALL be the integer seed modulo the snapshotted room count.
5. Settlement SHALL record terminal state and reclassify accounting only; it SHALL NOT call the payment token, prize receivers, treasury receiver, or OperatorFeeRouter. Registry interaction is permitted.
6. THE implementation SHALL NOT implement local BLS verification, alternative beacons, fallback randomness, blockhash/prevrandao entropy, administrator-selected outcomes, round cancellation, or refunds.
7. IF the committed beacon remains unavailable, THE round SHALL remain pending indefinitely with its obligations intact; neither pause nor a timeout SHALL substitute a new beacon or cancel the round.
8. THE implementation SHALL reject repeat settlement without modifying any liability, rollover, reward, or capacity counter.

### Requirement 8: Revenue allocation and percentage settlement incentive

**User Story:** As the protocol and its Operators, I want exactly conserved revenue from each funded round, including empty-room outcomes.

#### Acceptance Criteria

1. THE implementation SHALL calculate allocations once from aggregate gross entries at settlement, not by summing per-purchase rounded fees.
2. With `B = 10_000`, THE player contribution SHALL be `floor(gross * potBps / B)`, Operator revenue SHALL be `floor(gross * operatorBps / B)`, and gross treasury revenue SHALL be the complementary `gross - playerContribution - operatorRevenue`.
3. THE settlement reward SHALL be `floor(grossTreasury * settlementTipBps / B)`; THE net treasury allocation SHALL be `grossTreasury - reward`.
4. THE settlement reward SHALL be credited to the successful settlement caller in the payment asset and delivered through a separate pull-based claim.
5. THE reward SHALL NOT reduce the player pot or Operator share and SHALL NOT be calculated on inherited rollover, direct donations, expired prizes, or previous settlement credits.
6. THE exact identity `playerContribution + operatorRevenue + netTreasury + reward == gross` SHALL hold for all representable supported configurations and receipts.
7. THE implementation SHALL allocate Operator revenue, net treasury revenue, and the reward on both populated- and empty-winning-room outcomes.
8. Finalizer credits SHALL NOT expire under the player 30-day claim rule; the configured percentage is an incentive, not a guarantee that every settlement is economically profitable to execute.

### Requirement 9: Simple next-round rollover

**User Story:** As a player, I want an empty-room pot to become the next round's pot without an administrator moving funds.

#### Acceptance Criteria

1. IF the selected room has no tickets, THE implementation SHALL create no player claims and SHALL move that round's entire player pot into pending rollover for the same configuration version.
2. WHEN that configuration next opens a round, THE implementation SHALL atomically attach all pending rollover to the new round, clear the pending amount, and preserve exact per-token accounting.
3. THE implementation SHALL NOT charge entry allocations or settlement rewards on inherited rollover.
4. THE rollover SHALL remain a recorded player-pool obligation and SHALL NOT be treated as a donation, treasury surplus, or expired winning prize.
5. THE rollover SHALL be transferred into a successor round at most once; repeated empty outcomes SHALL carry the accumulated player pot forward without duplication.
6. Settlement SHALL NOT require a successor to be opened or funded, an approved asset, an enabled configuration, or an unpaused contract.
7. IF a configuration remains disabled or its asset remains removed, pending rollover SHALL remain attached to that configuration without expiry or an administrative sweep; re-enabling that same configuration and asset SHALL permit the normal successor opening.
8. THE implementation SHALL NOT introduce cross-configuration jackpot sharing, rollover migration, auctioned capture, or transaction-order-dependent selection among concurrent configurations.

### Requirement 10: Pro-rata distribution without Sybil or claim-order advantage

**User Story:** As a winning ticket holder, I want my entitlement to depend only on my tickets, not wallet count or claim order.

#### Acceptance Criteria

1. IF the winning room has `W > 0` tickets and the player pot is `P`, THE implementation SHALL record `payoutPerTicket = floor(P / W)` and distributable prize `payoutPerTicket * W`.
2. THE implementation SHALL move `P % W` into the configuration's pending next-round pot at settlement, not award it to the first or last claimant.
3. A user's entitlement SHALL equal that user's ticket count in the winning room multiplied by the recorded payout per ticket; it SHALL NOT be recomputed from remaining prizes or remaining tickets.
4. Splitting a winning holding among addresses or merging it into one address SHALL yield exactly the same total entitlement before gas costs.
5. THE implementation SHALL NOT iterate through users, winning tickets, or historical purchases to settle or calculate an individual claim.
6. IF a prize is too small to distribute one base unit per winning ticket, THE implementation SHALL carry the indivisible amount forward and SHALL NOT invent a nonzero claim.
7. Room totals and recorded user ticket counts SHALL remain available after claims; independent claim-consumption state SHALL prevent repeat payment.

### Requirement 11: Pull-based player and finalizer claims

**User Story:** As a claimant, I want a safe, independently retryable payout to a receiver I select.

#### Acceptance Criteria

1. THE contract SHALL allow a winning ticket holder to claim their entire round entitlement once, only after settlement and strictly before the claim deadline.
2. THE implementation SHALL authenticate the caller's entitlement and SHALL reject zero-address or Diamond-self receivers, losing-room-only holders, zero entitlements, and repeated claims.
3. THE implementation SHALL consume entitlement and decrement both round-level and per-token prize liabilities before the outbound token interaction.
4. IF the transfer reverts or reports failure through SafeERC20, THEN the complete claim SHALL revert, preserving entitlement and liabilities for retry.
5. A failed player claim SHALL NOT reverse settlement or block another player's claim, another round, or another token.
6. THE implementation SHALL allow finalizers to claim their aggregated credits per token with the same CEI, receiver-validation, and retry behavior.
7. Neither current token approval, configuration enablement, nor guardian pause SHALL gate existing player or finalizer claims.

### Requirement 12: Thirty-day player prize expiry

**User Story:** As the protocol, I want unclaimed prizes to become treasury revenue after a known, immutable claim window.

#### Acceptance Criteria

1. THE player claim deadline SHALL be the round's settlement timestamp plus exactly `30 days`; delayed settlement SHALL NOT shorten the post-settlement window.
2. WHEN `block.timestamp >= claimDeadline`, THE implementation SHALL reject player claims whether or not a separate expiry transaction has executed.
3. Any account SHALL be able to reclassify a settled populated-room round's remaining prize liability into treasury revenue at or after the deadline.
4. Prize expiry SHALL decrement the same round's remaining prize liability and the matching per-token aggregate by exactly the amount credited to treasury, without transferring assets or iterating winners.
5. THE implementation SHALL record one-shot expiry completion; subsequent expiry attempts SHALL NOT create treasury revenue again or reopen claims.
6. Empty-room rollover, rounding rollover, finalizer credits, and pending Operator revenue SHALL NOT be subject to player prize expiry.
7. Pause, configuration disablement, and asset removal SHALL NOT prevent expiry processing or subsequent treasury delivery; an unprocessed expired amount SHALL remain accounted until its reclassification transaction executes.

### Requirement 13: Fiddy-style OperatorFeeRouter delivery

**User Story:** As an Operator, I want Rooms to fund the shared Router in the original payment token without settlement depending on Router availability.

#### Acceptance Criteria

1. THE implementation SHALL bucket Operator revenue by the round's snapshotted integration version and payment token and maintain a matching per-token aggregate liability.
2. Any account SHALL be able to flush a positive amount up to the selected bucket exclusively to that integration version's OperatorFeeRouter.
3. WHEN opening a configuration with a nonzero Operator share, and again when flushing, THE implementation SHALL check the Fiddy readiness conditions: bootstrap finalized, positive effective weight, registered asset, and enabled Router deposits for that asset.
4. A flush SHALL reduce the bucket and aggregate before interaction, approve only the contribution amount, call `addRewards(asset, amount)`, and clear the allowance; it SHALL NOT leave a standing unlimited approval.
5. IF readiness, approval, token transfer, or Router delivery fails, THEN the flush SHALL revert atomically and preserve its pending liability for retry.
6. Removing an asset or changing current integrations SHALL NOT redirect or erase historical Operator liabilities.
7. THE implementation SHALL NOT reproduce Operator ownership, reward indexes, multipliers, or individual Operator claims inside Rooms, and SHALL NOT swap or wrap the contribution asset.

### Requirement 14: Treasury revenue, donations, and native rejection

**User Story:** As treasury, I want protocol revenue and genuine donations delivered without withdrawing player or Operator obligations.

#### Acceptance Criteria

1. Any account SHALL be able to flush an amount bounded by recorded treasury revenue to the current authority-configured treasury receiver; the caller SHALL NOT choose a different destination.
2. THE implementation SHALL compute token surplus as `max(balance - all recorded token obligations, 0)` only for known canonical assets and SHALL reject arbitrary unknown token addresses before querying their balances.
3. Any account SHALL be able to absorb token surplus into treasury revenue; repeated absorption without new excess SHALL NOT create additional revenue.
4. THE surplus obligation sum SHALL include unsettled inherited rollover, pending rollover, unclaimed prizes including expired-but-unprocessed prizes, finalizer credits, Operator revenue, and existing treasury revenue.
5. Direct donations SHALL NOT increase ticket receipts, the player allocation, rollover, Operator revenue, or the settlement-reward base.
6. THE Diamond SHALL reject ordinary native receipts and every value-bearing fallback call; no Rooms entrypoint SHALL accept native ETH as ticket principal.
7. IF native ETH is forced into the Diamond, any account SHALL be able to flush that native balance exclusively to treasury without touching ERC-20 accounting.
8. A failed treasury/native delivery SHALL revert atomically and preserve the corresponding balance/liability for retry; removing token approval SHALL NOT disable historical treasury handling.

### Requirement 15: Guardian pause preserving exits

**User Story:** As a guardian, I want to stop new exposure without preventing existing obligations from progressing.

#### Acceptance Criteria

1. THE guardian SHALL be able to pause opening and ticket purchases immediately and SHALL NOT be able to unpause, upgrade, withdraw funds, edit configurations, or choose outcomes.
2. THE authority SHALL be able to pause, unpause, and replace the guardian.
3. Pause SHALL NOT block the deadline cutoff, settlement, player claims before expiry, expiry processing, finalizer claims, Router retries, treasury delivery, surplus handling, or views.
4. Pausing SHALL NOT extend sales or claim deadlines, alter a randomness target, cancel a round, or create refunds.
5. A successor opening attempted while paused SHALL fail without consuming pending rollover; permissionless settlement SHALL remain independently callable.
6. THE public surface SHALL expose pause state and guardian identity and emit changes.

### Requirement 16: Timelocked upgrades and progressive code immutability

**User Story:** As a participant, I want observable governance and an irreversible path to fixed code after safe operation.

#### Acceptance Criteria

1. THE Diamond SHALL use Fiddy's single-authority model; production authority SHALL be an external timelock/governance executor whose delay and powers are verified before deployment.
2. Before finalization, only the authority SHALL be able to perform Diamond cuts or their initialization delegatecalls; initialization SHALL be atomic, authority-checked, and protected against replay.
3. THE implementation SHALL preserve the Fiddy selector bookkeeping, dispatch revert propagation, and loupe behavior; Rooms application storage SHALL use explicit namespaces with append-only upgrade layouts.
4. THE authority SHALL be able to call `finalizeProtocol()` to permanently disable cuts; THE implementation SHALL provide no reset or bypass of that latch.
5. Finalization SHALL NOT disable installed functions, wipe liabilities, renounce configuration governance, remove asset management, or block claims and revenue delivery.
6. THE documentation SHALL disclose that, before finalization, an upgrade authority can install arbitrary delegatecall logic; a timelock is not a cryptographic restriction against an approved malicious upgrade.
7. THE plan SHALL NOT require finalization on a fixed schedule or imply that finalizing code also eliminates token, Registry, Router, sequencer, or governance dependencies.

### Requirement 17: Versioned integrations protecting historical rounds

**User Story:** As a participant, I want configuration of future integrations not to rewrite historical randomness or revenue destinations.

#### Acceptance Criteria

1. THE authority SHALL be able to append immutable integration versions containing Registry and OperatorFeeRouter contract addresses and select the newest version for future openings.
2. A round SHALL snapshot its integration version and SHALL continue using that Registry for its committed target and that Router for its Operator bucket.
3. THE implementation SHALL reject nonexistent versions and invalid contract endpoints before opening; no participant SHALL supply a substitute integration address in a purchase, settlement, or flush.
4. Integration updates SHALL NOT migrate an active round, replace a committed target, or reroute an existing Operator bucket.
5. The Registry integration SHALL use its stable consumer API; Rooms SHALL NOT copy the Registry verifier, cryptographic helpers, trust anchor, or cache into its own custody contract.

### Requirement 18: Per-asset conservation and aggregate consistency

**User Story:** As an auditor, I want every token unit assigned to one obligation category and independently backed.

#### Acceptance Criteria

1. For each known asset, THE accounting SHALL maintain unsettled escrow, player prize liability, pending rollover liability, finalizer liability, pending Operator revenue, and treasury revenue as disjoint categories.
2. Unsettled escrow SHALL include a round's gross entries plus its inherited rollover; a historical receipt or prize-total statistic SHALL NOT be counted again as an additional liability.
3. For a supported asset, THE balance SHALL be at least the sum of its categories; without external donations or delivery anomalies, equality SHALL hold.
4. THE per-token pending-rollover aggregate SHALL equal the sum of that token's pending amounts across configurations; attached rollover SHALL instead be included in escrow.
5. THE player, finalizer, Operator, escrow, and treasury aggregates SHALL equal their corresponding outstanding source ledgers; claim expiry SHALL reclassify rather than destroy obligations.
6. Every settlement, rollover attachment, or expiry transition SHALL preserve the obligation sum; a deposit SHALL increase it by the exact supported-token payment; delivery SHALL decrease it by the amount delivered.
7. THE implementation SHALL NOT use another token's surplus to satisfy a shortfall, debit another round's prize to pay a claim, or make player/Operator obligations treasury-withdrawable.
8. A failure or revert in a value-moving transaction SHALL preserve all ledgers, capacities, and allowances according to EVM atomicity.

### Requirement 19: Public views and event reconstruction

**User Story:** As a player or independent frontend builder, I want to inspect occupancy, terms, expected payouts, and claim deadlines without a privileged backend.

#### Acceptance Criteria

1. THE public interface SHALL expose configuration and integration versions, current approvals, historical known assets, per-configuration active round and pending rollover, concurrency capacity, and governance state.
2. THE public interface SHALL expose round terms/status, original deadline, ticket supply and remaining tickets, current epoch/multiplier/unit price, recorded sellout/effective close, exact room totals, total tickets, user room counts, original deadline and selected beacon targets, inherited rollover, winning room, payout per ticket, remaining prize, claim deadline, and expiry state.
3. THE public interface SHALL expose per-token accounting and caller-specific player/finalizer entitlements; an expired or already-consumed player entitlement SHALL read as zero.
4. A purchase quote SHALL expose the execution-time epoch, multiplier, rounded unit price, full payment, and remaining supply. A payout preview SHALL use that round's actual receipts and inherited rollover and price proposed added tickets at the current epoch when sales are open and supply permits. It SHALL identify the result as conditional on room selection, transaction inclusion, epoch at execution, and final occupancy, not a guaranteed return. Closed-round previews SHALL reject positive proposed additions; zero-addition previews MAY show the existing conditional pot.
5. Events SHALL identify enough configuration, round, token, room, quantity, epoch, unit price, amount paid, supply, close reason, original/selected beacon, allocation, rollover, claim, expiry, integration, and receiver context to reconstruct economic transitions and treasury movements. Sellout target selection SHALL emit the prior and selected targets and cutoff timestamp, including when the target values coincide.
6. Full room occupancy reads MAY loop over at most 24 rooms; state-changing purchase, settlement, claim, and expiry paths SHALL NOT contain participant-dependent loops.
7. The interface SHALL NOT require wallet connection for public occupancy reads, privileged API access, or individual ticket enumeration.

### Requirement 20: Reentrancy and independent retry semantics

**User Story:** As a participant, I want one failed delivery or callback not to corrupt or block unrelated obligations.

#### Acceptance Criteria

1. THE implementation SHALL share one initialized Diamond-wide reentrancy guard across all Rooms entrypoints that interact externally or change value-bearing ledgers, including settlement and surplus reconciliation.
2. THE implementation SHALL follow checks-effects-interactions and SafeERC20 failure handling; settlement's necessary Registry call SHALL occur before terminal accounting is recorded under the same guard.
3. IF a callback attempts another guarded entrypoint, THEN THE transaction SHALL reject the nested operation without exposing a second claim, settlement, rollover consumption, surplus absorption, or flush.
4. Failed proof submission SHALL preserve the unsettled round; failed claims or revenue delivery SHALL preserve their independent entitlements without reverting an earlier successful settlement.
5. THE implementation SHALL NOT silently substitute recipients, providers, tokens, outcomes, or zero-success fallbacks when an external interaction fails.

### Requirement 21: Explicit gameplay and trust boundaries

**User Story:** As a player, I want to understand the intentional strategy and the risks that contracts cannot remove.

#### Acceptance Criteria

1. THE design SHALL preserve public crowding strategy, late additional purchases while supply remains, multiple-room holdings, and whale participation without per-wallet anti-Sybil caps, hidden occupancy, commit-reveal entries, or room switching of existing tickets. Increasing epoch prices SHALL reward earlier entry through lower cost for equal prize weight; the documentation SHALL NOT claim that higher late prices eliminate dilution or all benefits of waiting for occupancy information.
2. THE documentation SHALL state that cutoff inclusion and ordering depend on the chain/sequencer; public room data does not guarantee a last-second transaction will be included, secure remaining supply, execute in its quoted epoch, or remain undiluted. Caller maximum-payment protection SHALL bound the actual charge across epoch boundaries.
3. THE documentation SHALL explain that the empty-room probability is the fraction of rooms actually empty, not a function of address count; low-occupancy configurations can roll repeatedly without subsidy.
4. THE design SHALL document modulo bias for non-power-of-two room counts as negligible rather than claim exact uniformity, and SHALL not add rejection-sampling machinery for this range.
5. THE documentation SHALL disclose the 30-day forfeiture boundary, unpause/upgrade powers, public ticket holdings, token issuer controls, Router/Registry liveness, and the inability to refund a pending beacon.
6. THE documented guarantees SHALL be conditional on supported token behavior, the pinned compiler/client semantics, Registry correctness, and the accepted chain assumptions.
7. THE package SHALL distinguish source inspection, local tests, formal results, fork checks, and live execution; Fiddy's historical rehearsal SHALL NOT be represented as Rooms evidence or as a live rehearsal of its new deadline-draw implementation.

### Requirement 22: Reviewable implementation and release validation

**User Story:** As a maintainer, I want a small traceable implementation and evidence sufficient to reason about the complete state machine.

#### Acceptance Criteria

1. THE implementation plan SHALL map each task to numbered acceptance criteria, reuse pinned source patterns, and separate infrastructure, core lifecycle, settlement, exits, and integration into reviewable slices.
2. Validation SHALL include actual supported-token approvals/transfers, four-epoch price and rounding boundaries, caller maximum payments, remaining-supply races, sellout including on the first purchase, unsold deadline draws, concurrent configurations and tokens, winning and empty outcomes, repeated rollover, donations, removal/pause boundaries, claim expiry, Router retries, and Diamond finalization with continuing operation.
3. Stateful invariant and arithmetic/property testing SHALL cover conservation, solvency, source-ledger aggregates, ticket supply bounds, equal prize weight across epochs, purchase-splitting price neutrality within an epoch, no double claims, no double rollover, immutable snapshots, only the prescribed one-shot sellout target selection, and terminal monotonicity.
4. Formal work, if undertaken, SHALL use the approved remote verification environment rather than run local prover workloads; authoritative results and internal review materials SHALL remain outside public version control, with only appropriate summaries included.
5. The release plan SHALL require concrete target-client/Registry integration evidence and a fresh authorized Robinhood Testnet lifecycle using an actual committed Quicknet beacon, not only mocked randomness.
6. Compiler/settings, dependency/source pins, chain IDs, addresses, selectors, configuration inputs, and runtime hashes SHALL be recorded and validated for an implementation release without publishing credentials, private endpoints, machine names, or local filesystem paths.
7. This implementation delivery SHALL produce sixteen incremental feature-branch PRs, with subtask commit slices and the final checkpoint in PR 16. It SHALL prepare and locally exercise rehearsal tooling without live signing, deployment, broadcasting, or finalization.
8. Implementation, commits and feature-branch publication are authorized for this delivery. Deployment and code finalization remain separate authorization boundaries. The sole default-branch write is the authorized README-only root commit; no PR may be merged automatically.
