# Implementation Plan: Rooms

## Overview

Build the reviewed Rooms design bottom-up using Fiddy's pinned Diamond infrastructure and operating patterns. Keep custody independent, use only approved ERC-20s, and implement one active sellout-or-deadline round per configuration with 2–24 rooms, a configured ticket supply, four equal time epochs priced at 1.00x/1.25x/1.50x/1.75x base price, equal prize weight per ticket, immutable snapshots, shared Registry randomness, simple next-round rollover, Router revenue, pull claims, and 30-day player expiry. Checkboxes record completed work; validation evidence distinguishes local, formal, and unexecuted live paths.

This package is the accepted implementation plan. Read [requirements.md](requirements.md) and [design.md](design.md) first. Specification approval and implementation authorization are separate from publication or deployment. All proposed code paths are new Rooms files unless explicitly identified as Fiddy-derived copies. Do not change either reference repository. Do not create another checkout merely to begin a stage; reuse the project's working checkout and feature branches. There are no agent merge or default-branch-write tasks.

Delivery uses one PR per parent task 1–16 and commits per subtask. Task 17 is included in PR 16. Each PR targets its predecessor. All remain open and unmerged. The authorized README-only root commit is the sole default-branch write. Live rehearsal execution is prepared but unexecuted.

## Tasks

- [x] 1. Review the specification and pin implementation inputs
  - [x] 1.1 Confirm the settlement-reward denominator and dust destination.
    - Details: Use the accepted treasury-gross-based percentage, deducted only from treasury, and per-ticket division remainder into the next configuration pot. The 30-day period applies to player prizes, not earned finalizer or pending Operator liabilities. Update the three root documents together for accepted revisions before writing contracts.
    - _Requirements: 8.1–8.8, 10.1–10.7, 12.1–12.7, 22.7–22.8_
  - [x] 1.2 Freeze source, toolchain, and licensing inputs.
    - Details: Record Fiddy main `795425ef6a8830278b56b9052aa2271e92930eb3` and Registry main `118a94d2e447055d1a47d1a13488e887aaa4a822` as the reviewed source baseline. Inspect the exact dependency revisions used for OpenZeppelin, Registry, Router, and test utilities; do not assume Fiddy's Registry submodule is current Registry main. Preserve upstream notices and preserve owner-authorized derivative publication terms and record any production licensing gate. Use the explicitly approved Solidity 0.8.33 compiler with Fiddy's 200 optimizer runs/Osaka settings.
    - _Requirements: 1.1, 1.4, 1.6, 17.5, 21.6–21.7, 22.1, 22.6_
  - [x] 1.3 Define explicit fixtures and the external-authority policy; leave launch configuration unset.
    - Details: Define explicit local test assets, prices, supplies, durations, delays, purchase limits, tip percentage and capacity, with 50/20/30 initial economics. Document the external timelock/guardian/treasury policy. Production addresses, prices, supplies and initial configurations remain unset; verification of actual external timelock roles/delay and license parameters remains a release gate. Fixed E1–E4 multipliers affect price only and all tickets have equal prize weight.
    - _Requirements: 2.1–2.8, 3.1–3.8, 6.6–6.7, 15.1–15.6, 16.1, 16.6–16.7, 21.5–21.6, 22.6_

- [x] 2. Establish the minimal Diamond and isolated storage
  - [x] 2.1 Add the implementation toolchain and pinned dependencies only after implementation is authorized.
    - New files: `foundry.toml`, dependency/remapping declarations, project CI workflow, and applicable license/provenance declarations.
    - Details: Match reference compiler conventions; preserve a narrow local test profile and explicit broader CI-owned gates. Do not add frontend, token/NFT contracts, a factory, or generic vault dependencies.
    - _Requirements: 1.1–1.6, 22.1, 22.6–22.8_
  - [x] 2.2 Copy Fiddy Diamond plumbing and define Rooms application types/storage.
    - New files: `src/RoomsDiamond.sol`, `src/libraries/LibDiamond.sol`, cut/loupe facets and interfaces, `src/shared/DiamondTypes.sol`, `src/shared/Types.sol`, `src/shared/Errors.sol`, `src/libraries/LibRoomsStorage.sol`.
    - Details: Preserve Fiddy selector dispatch, code checks, authority semantics, revert propagation, finalization latch, and native rejection. Use fresh Rooms application namespaces, uint256 amounts/ticket supply/totals, pending rollover per config, round/user/room counts, original deadline and selected targets, sellout/effective-close timestamps, independent claim markers, and expiry state. Do not import Fiddy's narrower capped-ticket arithmetic assumptions or legacy refund layout.
    - _Requirements: 1.1–1.6, 2.6–2.8, 5.2, 5.5, 10.7, 14.6–14.7, 16.2–16.5, 18.1–18.8_
  - [x] 2.3 Implement atomic one-time initialization and the shared guard.
    - New files: `src/initializers/RoomsInit.sol`, `src/libraries/LibReentrancy.sol`, `test/RoomsDiamond.t.sol`, `test/RoomsInit.t.sol`.
    - Details: Authority-match validation, role checks, guard initialization, approved assets, initial integration/config snapshots, and events happen in the approved initial cut. Exercise the actual Diamond through add/replace/remove, rejected unauthorized cuts, initializer replay, a storage-preserving upgrade, finalization, and continued installed operation. Do not claim broad initialization confidence from direct facet-only calls.
    - _Requirements: 1.5–1.6, 16.1–16.7, 20.1–20.5, 22.2_

- [x] 3. Implement future-round configuration, approval, and integration governance
  - [x] 3.1 Implement immutable configuration versions and validation.
    - New files: `src/libraries/LibRoomsConfig.sol`, `src/interfaces/IGovernance.sol`, `src/facets/GovernanceFacet.sol`, `test/RoomsConfig.t.sol`.
    - Details: Positive base price and total ticket supply; duration at least four seconds; arbitrary integer room counts 2–24; player/Operator gross BPS with positive residual treasury; treasury-based reward BPS below 100%; zero optional purchase limit means no additional per-purchase cap, without bypassing supply. Four epoch multipliers are fixed protocol constants. Create versions disabled by default outside initialization. Reject invalid values using widened arithmetic. Test meaningful boundary/error behavior, including 3/7/24 rooms, invalid short durations, and receipts beyond Fiddy's uint128 bound.
    - _Requirements: 2.1–2.8, 8.2–8.6, 21.4, 22.1_
  - [x] 3.2 Add current approval and permanent known-asset state.
    - Modified files: governance, initializer, and accounting storage; new coverage in `test/RoomsGovernance.t.sol`.
    - Details: Explicit timelocked approve/remove; only nonzero contracts other than Diamond; retain known assets forever for historical exits/surplus. No FoT/rebase compatibility code or per-transfer balance-delta wrapper. Record the supported-token/alias admission assumptions and prove removing approval cannot erase historical records.
    - _Requirements: 3.1–3.8, 14.2, 14.8, 18.7, 21.5–21.6_
  - [x] 3.3 Add versioned integrations, concurrency settings, treasury routing, guardian, and finalization selectors.
    - Modified files: governance and initialization; new integration interfaces and governance tests.
    - Details: Immutable Registry/Router pairs, no historical replacement, enable flags, active-round limit, pause-only guardian, authority-only unpause, validated treasury receiver, and `finalizeProtocol`. Finalization must leave operational configuration governance functional. Do not implement a custom timelock or authority-renunciation mechanism.
    - _Requirements: 4.3–4.4, 4.7, 13.6, 14.1, 15.1–15.6, 16.1–16.7, 17.1–17.5_

- [x] 4. Implement epoch-priced purchases and sellout-or-deadline commitments
  - [x] 4.1 Add the single-room counted purchase path.
    - New files: `src/interfaces/IRooms.sol`, `src/facets/RoomsFacet.sol`, epoch/price helpers in `src/libraries/LibRoomsMath.sol`, `test/RoomsPurchases.t.sol`, reusable supported-token/integration setup.
    - Details: Validate round/room/quantity/limit/approval/pause and remaining supply. Derive epoch from the execution timestamp and original duration, round unit price upward before multiplying quantity, and enforce caller `maxPayment`. Record user and room counts, actual payment receipts, and escrow, then SafeERC20 transfer. Test E1–E4, exact epoch boundaries, durations not divisible by four, low-base-unit rounding, same-epoch purchase partitioning, prices beyond uint96, stale maximum payments, overbuy reverts without partial fills, and remaining-supply races. Repeated purchases and multiple-room holdings retain equal prize weight without individual ticket IDs or participant loops. Do not add per-wallet caps, transfers, switching, or batch-entry scope.
    - _Requirements: 2.7, 3.2–3.7, 4.7, 5.1–5.7, 6.4, 14.5, 20.1–20.5, 21.1–21.2_
  - [x] 4.2 Implement configuration-scoped opening and inherited-pot attachment.
    - Modified files: RoomsFacet and storage; new opening/concurrency scenarios.
    - Details: Enforce enabled config, approved asset, one active round/config, global capacity, and Router readiness for nonzero Operator share. Snapshot configuration/integration, reserve the pointer/capacity, consume pending pot into round escrow, and bundle the first purchase. Verify a failed first transfer restores both the old pot and all admission state.
    - _Requirements: 2.5, 3.2–3.4, 4.1–4.7, 9.2, 9.5–9.8, 13.3, 17.1–17.4, 18.2, 18.4, 18.6, 18.8_
  - [x] 4.3 Commit the deadline target and implement atomic early sellout selection.
    - New file: `src/interfaces/IEqualFiDrandRegistry.sol`; modified opening tests.
    - Details: At opening retain `firstRoundAfter(closesAt + delay)` as original deadline target and initial selected target; initialize effective close to deadline. Only an exact-fill purchase before deadline sets SoldOut and sellout/effective-close timestamps and selects `firstRoundAfter(soldOutAt + delay)` from the same Registry. Both commitments require nonzero target, strict `roundTime`, and cache absence. Preserve original target; emit both targets even when identical. Cover sellout in every epoch and on first purchase, no further purchases after sellout, no capacity release before settlement, final-purchase token/Registry failure rollback, strict deadline equality, unsold deadline with no reselection, same-target selection, late opening failure, and rejection of second selection or caller choice between beacons. Epoch changes and future config/integration changes cannot mutate snapshots or select targets. Keep L2 time assumptions explicit rather than claiming wall-clock secrecy.
    - _Requirements: 4.5–4.6, 5.5, 6.1–6.7, 17.2–17.5, 18.8, 19.5, 21.2, 21.6–21.7_

- [x] 5. Checkpoint - Verify Diamond, governance, and opening behavior
  - Details: Run focused Diamond/configuration/governance/purchase tests and exercise an actual local Diamond with real supported-token approvals/transfers and concurrent configurations. Reconcile epoch prices and actual receipts, remaining supply, original/selected targets, snapshots, capacities, ticket totals, and attached/pending pot backing for early sellout and unsold deadline closure. Ask for review only for material unresolved behavior; no automatic implementation or release scope expansion.
  - _Requirements: 1.1–6.7, 15.1–17.5, 18.1–18.8, 20.1–20.5, 22.1–22.3_

- [x] 6. Implement allocation math and exact-beacon settlement
  - [x] 6.1 Implement full-width allocation and deterministic per-ticket math.
    - Modified file: `src/libraries/LibRoomsMath.sol`; new arithmetic fuzz coverage.
    - Details: Implement shared epoch selection and ceiling-rounded unit-price math for purchases/quotes/previews. Compute player and Operator floors from actual aggregate epoch-priced gross, complement treasury, calculate treasury-funded percentage reward, and split player pot into distributable and remainder. Cover non-divisible-duration epoch boundaries, coarse-unit prices, same-epoch purchase partitioning, equal prize weight across epochs, tiny/zero rounded allocations, large representable receipts, high valid BPS, positive treasury retention, and arbitrary wallet partitions. Do not reuse Fiddy's capped uint128/unchecked allocation helper unchanged.
    - _Requirements: 2.3–2.4, 5.1–5.7, 8.1–8.8, 10.1–10.6, 18.1–18.8_
  - [x] 6.2 Implement proof supply/cache reuse and terminal settlement.
    - New files: `src/interfaces/ISettlement.sol`, `src/facets/SettlementFacet.sol`, `test/RoomsSettlement.t.sol`.
    - Details: Require SoldOut or Open past deadline; use only the selected target, `hasSig` and `postedAt > effectiveClose`, domain separation with Diamond/chain/round, modulo by snapshotted room count, and one-shot terminal transition. Cache reuse ignores supplied proof bytes. Test sellout settlement before original deadline, unsold deadline settlement from actual mixed-epoch receipts, original-target rejection after selection of a distinct sellout target, unavailable selected target without fallback, invalid-proof rollback, no post-close target changes, zero-randomness sentinel avoidance, one-ticket rounds, and independent concurrent settlements. Do not implement BLS, refunds, or fallback entropy.
    - _Requirements: 1.5, 6.1–6.7, 7.1–7.8, 17.1–17.5, 20.1–20.5, 21.4, 21.6–21.7_
  - [x] 6.3 Record allocations and release active capacity without delivery.
    - Modified files: settlement, accounting source ledgers, and settlement tests.
    - Details: Credit Operator buckets by snapshotted integration/token, finalizer by caller/token, and treasury; debit receipts plus inherited pot from escrow; release pointer/count. Demonstrate a reverting token receiver or unavailable Router cannot block settlement, and repeated settlement cannot credit anything twice.
    - _Requirements: 4.5–4.6, 7.5, 7.8, 8.1–8.8, 13.1, 18.1–18.8, 20.4_

- [x] 7. Implement empty-room and rounding rollover through the same successor-pot path
  - [x] 7.1 Add empty-room settlement into configuration pending rollover.
    - New file: `test/RoomsRollover.t.sol`; modified settlement branches.
    - Details: Move the full own-plus-inherited player pot into pending storage and its per-token aggregate; create no claim or expiry deadline. Next opening consumes it exactly once. Cover repeated empty outcomes, two configurations sharing an asset without sharing pots, and cross-token separation. Fees and tips apply only to new receipts.
    - _Requirements: 8.5, 8.7, 9.1–9.8, 10.6, 12.6, 18.1–18.8_
  - [x] 7.2 Add populated-room per-ticket prize and remainder handling.
    - Modified files: settlement and rollover tests.
    - Details: Store per-ticket payout and remaining distributable liability, move only indivisible remainder to the same pending pot, set settlement-relative claim deadline. Cover a successor round holding prior rollover, dust-only outcomes, and the no-double-liability invariant for historical pot statistics. Pause/disable/removal can delay successor opening but cannot force settlement to fail or sweep the pot.
    - _Requirements: 9.1–9.8, 10.1–10.7, 12.1, 12.6, 15.3–15.5, 18.2–18.6_

- [x] 8. Implement player claims, fixed expiry, and finalizer claims
  - [x] 8.1 Add one-shot pull prize claims.
    - New files: `src/interfaces/IClaims.sol`, `src/facets/ClaimsFacet.sol`, `test/RoomsClaims.t.sol`.
    - Details: Caller authentication, immutable ticket history, independent consumption marker, fixed per-ticket multiplication, valid receiver, positive entitlement, round/aggregate decrement before SafeERC20 transfer. Verify split versus merged wallets and varied claim ordering produce identical aggregate payments, and failed/reentrant claims preserve retryability.
    - _Requirements: 5.7, 10.1–10.7, 11.1–11.5, 11.7, 18.1–18.8, 20.1–20.5_
  - [x] 8.2 Add permissionless 30-day expiry reclassification.
    - New file: `test/RoomsExpiry.t.sol`; modified ClaimsFacet and round accounting.
    - Details: Fixed `settledAt + 30 days`; claim accepted immediately before and rejected exactly at/after deadline whether or not expiry ran. Expiry moves only remaining player prizes to treasury once, without user iteration or token transfer. Test partial/all/zero claims, repeat calls, empty-room exclusion, delayed settlement, lazy-expiry surplus safety, and pause/asset-removal independence.
    - _Requirements: 2.8, 9.4, 10.6, 11.1, 12.1–12.7, 14.4, 15.3–15.4, 18.1–18.8_
  - [x] 8.3 Add per-token finalizer credit claims.
    - Modified files: ClaimsFacet, source ledgers, and claims tests.
    - Details: Aggregate settled rewards per finalizer/token; caller-selected valid receiver, consume before transfer, full rollback on failure, no player expiry treatment. Verify removed tokens and paused state do not block delivery, and unrelated assets/rounds remain independent.
    - _Requirements: 8.3–8.5, 8.8, 11.6–11.7, 12.6, 18.5–18.8, 20.1–20.5_

- [x] 9. Checkpoint - Verify all settlement, rollover, and prize transitions
  - Details: Run focused settlement/rollover/claims/expiry arithmetic and lifecycle tests. Execute a full local funded round, a deterministic empty-room successor chain, a populated successor with inherited pot, and a partially claimed round expired at the true fixed boundary. Reconcile every source ledger and account category. This is local execution, not live beacon or elapsed-live-time evidence.
  - _Requirements: 7.1–12.7, 18.1–18.8, 20.1–20.5, 22.2–22.3_

- [x] 10. Implement Operator and treasury delivery, donation reconciliation, and forced-native recovery
  - [x] 10.1 Add snapshotted Router contributions and retry semantics.
    - New files: `src/interfaces/IRevenue.sol`, `src/interfaces/IOperatorFeeRouter.sol`, `src/libraries/LibOperatorFeeRouter.sol`, `src/facets/RevenueFacet.sol`, `test/RoomsRevenue.t.sol`.
    - Details: Preserve Fiddy readiness and exact-sized-then-zero allowance pattern, no transfer-delta accommodation. Exercise controlled Router fixtures here; integrate the actual Router implementation in task 12.1. Prove failed funding preserves the version/token bucket, later successful funding uses the same asset, and current integration changes cannot reroute the bucket.
    - _Requirements: 3.4–3.7, 13.1–13.7, 17.1–17.5, 18.1–18.8, 20.1–20.5_
  - [x] 10.2 Add treasury delivery and safe supported-token surplus absorption.
    - Modified files: RevenueFacet and revenue integration tests.
    - Details: Permissionless, amount-capped delivery only to configured receiver; all obligation categories included in surplus; known-asset checks before balance queries. Exercise direct donations, repeated absorption, expired-but-unprocessed prizes, pending/attached rollover, old finalizer/Operator credits, removed-known assets, unknown token facades, and reverting receiver retry. Do not add arbitrary unknown-token recovery or deposit-triggered fees on donations.
    - _Requirements: 3.4, 3.6, 3.8, 9.4, 12.4, 12.7, 14.1–14.5, 14.8, 18.1–18.8, 20.1–20.5_
  - [x] 10.3 Confirm ordinary-native rejection and forced-native treasury delivery.
    - Modified files: shell/native branch and revenue tests; disposable force-send helper only in tests.
    - Details: Both receive and value-bearing fallback revert. Force native value using a purpose-built local helper and prove treasury-only recovery with no ERC-20 ledger change; preserve balance on failed native delivery. No wrapper, native entrypoint, or ordinary donation receive path.
    - _Requirements: 14.6–14.8, 18.7–18.8, 20.1–20.5_

- [x] 11. Implement public economic views and reconstruction events
  - [x] 11.1 Add bounded occupancy, entitlements, state, and accounting views.
    - New files: `src/interfaces/IRoomsView.sol`, `src/facets/RoomsViewFacet.sol`, `test/RoomsViews.t.sol`.
    - Details: All proposed views in design.md, including derived Locked and stored SoldOut phases, base/epoch prices, multiplier, supply/remaining tickets, purchase quotes, original/selected targets, sellout/effective close, active pointers, old/new approval status, source liabilities, pending pot, claim deadline, current/expired/consumed entitlement, exact room/user totals, and balance versus accounted total. Preserve user ticket history after claims. No privileged API, wallet-only reads, or participant enumeration.
    - _Requirements: 3.4, 4.6, 10.7, 12.2, 14.2–14.4, 15.6, 19.1–19.3, 19.6–19.7_
  - [x] 11.2 Add conditional payout previews and economically reconstructable events.
    - Modified files: interfaces/facets and view/lifecycle tests.
    - Details: Preview includes the hypothetical current-epoch payment in gross and ticket quantity in room totals, not inherited rollover as fee base. Reject positive proposed additions after either cutoff or above supply/quantity limit; permit zero-addition existing-pot previews while unsettled. Emit epoch/unit price/payment, remaining supply, close reason, and original/selected beacon facts from design.md without one event per individual ticket. Test quote/preview boundaries against actual purchases, execution in a later epoch with maximum-payment protection, and equal settled entitlements for equal ticket holdings bought in different epochs; do not add tests that merely assert getters echo storage or event wiring matches source text.
    - _Requirements: 5.6, 8.1–8.8, 9.1–9.5, 19.4–19.7, 21.1–21.4, 22.2_

- [x] 12. Prove complete local lifecycle and stateful accounting behavior
  - [x] 12.1 Build actual-Diamond, supported-token, Registry, and Router integration scenarios.
    - New file: `test/RoomsEndToEnd.t.sol`; reusable integration setup supporting actual Router and real Registry vectors where applicable.
    - Details: Trace mixed-epoch entries to early sellout and unsold deadline settlement, populated/empty successor pots, all delivery paths, claim expiry, pause/removal, config/integration changes, shared-token configurations, different tokens, and post-finalization continued play. Include a first-purchase sellout and a final-purchase failure/retry with unchanged pre-failure target and accounting. Mocked chosen-room scenarios remain separately labeled; no synthetic balance injection or direct storage patching in consumer lifecycle proof.
    - _Requirements: 1.1–1.6, 3.1–3.8, 4.1–4.7, 7.1–17.5, 18.1–18.8, 20.1–20.5, 21.7, 22.2–22.3_
  - [x] 12.2 Add stateful handlers and source-ledger invariants.
    - New file: `test/RoomsInvariant.t.sol`.
    - Details: Randomly interleave supported deposits, epoch-priced openings/purchases, time advancement across epoch/deadline boundaries, sellout selection, exact-selected-target cache/settlement, claims/expiry, donations/absorption, revenue retries, pause/removal, and new versions. Check conservation, solvency, actual-payment/source aggregates, supply bounds, same-epoch purchase-splitting neutrality, equal prize weight across epochs, counters/pointers, immutable terms/original targets, only the prescribed one-shot sellout selection, terminal monotonicity, no double claim/rollover/expiry, and independent tokens/configurations with a deterministic reference model. Use consistent reachable preconditions and witnesses rather than vacuous success paths.
    - _Requirements: 4.1–4.7, 6.1–6.7, 8.6, 9.1–9.8, 10.4, 12.1–12.7, 18.1–18.8, 20.1–20.5, 22.3_
  - [x] 12.3 Establish CI-owned release gates and measured costs.
    - Modified files: CI workflow, test profiles, release validation commands.
    - Details: Full suite, extended fuzz/invariant campaigns, static analysis, formatting/build checks, and deterministic dependency/runtime manifests. Use focused local checks while iterating. Measure actual purchase/settlement/claim/expiry/Router gas for 2/8/24 rooms and supported assets; do not publish remembered gas/dollar estimates or claim every configured reward pays gas. Exercise new paths directly; tests alone are not full runtime evidence.
    - _Requirements: 5.5, 8.8, 19.6, 21.6–21.7, 22.1–22.3, 22.6_

- [x] 13. Checkpoint - Reconcile the complete candidate and evidence boundaries
  - Details: Ensure all applicable CI-owned gates pass for the committed candidate when publication is authorized; run the actual local changed lifecycle and record what it proves. Review every acceptance criterion against design/tests without weakening inconvenient behavior. Separate mocked, real-contract local, fork, formal, and live claims. Resolve any missing requirements before calling the candidate complete.
  - _Requirements: 1.1–22.8_

- [x] 14. Complete bounded formal work and independent review before release
  - [x] 14.1 Define meaningful proof targets and execute only in the approved remote environment.
    - Local-only implementation-stage artifacts: formal harnesses, proof specifications, and durable raw outputs outside version control; only an appropriate high-level summary belongs in version control.
    - Details: Epoch-price and supply bounds, same-epoch purchase partition neutrality, allocation conservation from actual receipts, positive treasury, prescribed one-shot sellout selection, populated/empty rollover, pending attachment, one-shot claims/expiry, per-asset non-mutation, and initialization/finalization boundaries. Bind proof inputs to actual source, compiler/settings, runtime hashes, documented token/Registry/Router models, explicit bounds, and sanity witnesses. Do not probe or invoke local Halmos/Certora, or claim timeout/unknown/vacuity as a pass. Read the current approved execution instructions before starting remote work.
    - _Requirements: 8.6, 9.1–9.8, 10.1–10.7, 12.1–12.7, 16.1–16.7, 18.1–18.8, 21.6–21.7, 22.3–22.4, 22.6_
  - [x] 14.2 Review the committed candidate and remediate confirmed issues.
    - Details: Independent review of Diamond selectors/storage, initialization/authority, randomness assumptions, ERC-20 admission, aggregate accounting, claim expiry, rollover, Router contribution, surplus, and pause semantics. Keep internal reports/findings outside version control; apply concrete fixes in narrow candidate changes, update specs, and repeat affected evidence before release. Label agent review separately from third-party assurance.
    - _Requirements: 1.1–1.6, 3.1–3.8, 6.1–6.7, 7.1–20.5, 21.5–21.7, 22.1–22.6_

- [x] 15. Prepare a Robinhood Testnet rehearsal without live execution
  - [x] 15.1 Write deployment and read-only provenance validators.
    - New implementation-stage files: `script/DeployRooms.s.sol`, lifecycle helpers, validators, and public-safe deployment manifests.
    - Details: Guard chain ID 46630 for the rehearsal, validate official current chain configuration and actual dependency code/identity, installed authority/timelock roles, approved assets, Router readiness, Registry target-client behavior, compiled bytecode and selector/layout manifests. Load private runtime configuration only from approved secret storage without logging it. No guessed addresses, credentials, hostnames, local paths, or raw private evidence in public materials.
    - _Requirements: 1.6, 3.6, 6.6–6.7, 13.3, 16.1, 16.6, 17.1–17.5, 21.5–21.7, 22.5–22.6, 22.8_
  - [x] 15.2 Provide runnable rehearsal orchestration and exercise it locally without signing.
    - Details: Exercise local orchestration and prepare the future live sequence; mark live signing, broadcasting and finalization unexecuted. A later separately authorized rehearsal uses a fresh Rooms Diamond, actual epoch-priced approved-token transfers, verified Registry and Router, concurrent configurations/assets, early sellout and unsold deadline cutoff, selected actual future Quicknet proof and cached reuse, successful claims and revenues, a failed delivery followed by retry, and progressive finalization on disposable testnet state. Observe original/selected targets and effective closes; only the prescribed exact-fill sellout may select its future target. Obtain/observe empty-room rollover honestly without outcome-driven target changes; deterministic local tests provide branch coverage if a live outcome is not obtained. Do not change or reuse a finalized Fiddy deployment as Rooms.
    - _Requirements: 1.2–1.4, 4.1–4.7, 6.1–6.7, 7.1–7.8, 9.1–9.8, 11.1–11.7, 13.1–17.5, 21.7, 22.2, 22.5–22.8_
  - [x] 15.3 Validate receipt/event/accounting evidence against explicit fixtures.
    - Details: Provide evidence validators exercised against fixtures; live evidence remains prepared but unexecuted. Reconcile receipts, events, target beacon, runtime hashes, configuration/integration versions, source ledgers, and balances for the exact candidate. Fixed 30-day expiry is proven locally with controlled time; a same-day rehearsal is not a live 30-day observation. Any later actual live expiry result is separate evidence. Do not shorten the constant or upgrade the clock rule to manufacture coverage.
    - _Requirements: 2.8, 12.1–12.7, 18.1–18.8, 21.7, 22.2–22.6_

- [x] 16. Document operation and prepare the reviewable release handoff
  - [x] 16.1 Synchronize specifications and publishable protocol documentation.
    - Modified files: these three root documents; new implementation-stage accounting/randomness/governance/asset-policy/operator-integration/rehearsal documentation where required.
    - Details: Record final interfaces, storage/selector manifests, base prices and ticket supplies, four epoch price multipliers and rounding, maximum-payment protection, equal prize weight, sellout-or-deadline rules and target selection, current launch terms, the supported-token and alias assumptions, ordinary-native rejection, donations-to-treasury, simple per-config rollover including disabled-config inactivity, 30-day forfeiture, tip denominator, permissionless callers/incentives, and versioned integrations. Explain public holdings, the late-price premium without guaranteed elimination of dilution, supply races, repeated-empty economics, sequencer risk, upgrade authority, and code-versus-governance finalization. Provide direct-call ABI/commands without requiring a new frontend or private backend.
    - _Requirements: 1.6, 2.1–2.8, 3.5–3.8, 6.6–6.7, 8.8, 9.1–9.8, 12.1–12.7, 14.1–14.8, 15.1–17.5, 19.1–19.7, 21.1–21.7, 22.1–22.6_
  - [x] 16.2 Deliver candidate validation and governance handoff without automatic finalization or merging.
    - Details: Summarize exact source/runtime/config pins, exercised checks, high-level formal-evidence summary, and remaining limits. Publish feature-branch commits or open a PR only when authorized, leaving human integration untouched. Production deployment and eventual irreversible finalization each require explicit separate authority; do not schedule either because the checklist is complete. Finalization has no forced deadline.
    - _Requirements: 16.1–16.7, 21.5–21.7, 22.1–22.8_

- [x] 17. Final checkpoint - Verify complete behavior and passing release gates
  - Details: Ensure every acceptance criterion has observable implementation and appropriate passing evidence, all applicable tests/gates pass for the exact candidate, and no source/test/documentation drift remains. State unexecuted target-chain or elapsed-time evidence honestly. Hand off the reviewable result; do not merge, deploy production, or finalize without the required separate authorization.
  - _Requirements: 1.1–22.8_
