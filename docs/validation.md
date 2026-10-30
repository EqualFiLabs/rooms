# Validation evidence

## Opening acceptance checkpoint

The actual Diamond dispatches initialized governance and complete opening/purchase selectors. Tests deploy supported exact-transfer token fixtures and execute approvals and nominal transfers. Registry and Router are controlled fixtures at this checkpoint.

| Acceptance area | Observable coverage |
| --- | --- |
| Diamond and initialization | Add/replace/remove, storage preservation, authority/code checks, revert propagation, replay and atomic rollback, native rejection, finalization with continued installed operation |
| Governance | Immutable disabled-by-default configs, BPS/room/duration bounds, permanent asset history, versioned integrations, capacity, independent roles and pause-only guardian |
| Prices and counted holdings | Four epochs, exact boundaries, non-divisible duration, coarse-unit ceiling, equal ticket counts, partition-neutral payment, maximum-payment protection, uint96-exceeding unit price and uint128-exceeding receipts |
| Opening and supply | Actual paid opening, concurrent configurations and 18/6-decimal assets, nonzero purchase cap, no partial fills, remaining-supply races, transfer rollback, snapshot isolation and disabled-config continuing purchases |
| Draw commitment | Original deadline target retained, first-purchase and every-epoch sellout, same-target selection, strict future/uncached validation, original deadline equality, token callback observes completed sellout effects |
| Backing and capacity | Gross receipts equal escrow and actual balances, separate assets, inherited-pot component attachment/rollback, no release at either cutoff before settlement |

`RoomsOpeningIntegration` combines both sales cutoffs and admission changes in funded local scenarios. Inherited-pot attachment currently has component fixture coverage; complete empty-outcome generation and successor consumption will be exercised with settlement. No real BLS proof, live chain, Router delivery, prize claim or formal result is implied by this checkpoint.

## Settlement component boundary

Allocation properties exercise full-width receipts, complement treasury, treasury-funded tips and wallet-partition-neutral per-ticket arithmetic. Controlled Registry tests cover the selected target only, proof failure rollback, cached zero randomness, provenance after effective close and chain/Diamond/round domain separation. Common-allocation tests observe fee buckets and capacity release independently of token/Router delivery. These are internal components exposed only by test harnesses; the returned player pot is deliberately outside that component assertion. The release Diamond has no public settlement selector until both empty and populated outcomes are assembled together.

## Complete settlement assembly

The public settlement facet combines selected-beacon acquisition, common allocation and exactly one complete outcome. Actual-Diamond scenarios reconcile all six obligation categories against token balances after empty outcomes, populated successors, dust-only payouts and mixed-epoch deadline draws. Repeated empty component scenarios establish same-configuration attachment and independent asset/configuration pots; public scenarios also generate empty rollover and consume it at the next paid opening. Player claims and expiry are introduced separately. Controlled randomness is deterministic local branch coverage, not live-beacon evidence.

## Settlement and claims acceptance checkpoint

Funded public-Diamond scenarios generate repeated empty outcomes, attach inherited funds to a populated successor, partially claim and expire at the fixed boundary, then open another round. A separate reference calculation derives escrow, initial distributable prizes less payouts/expiry, configuration pots, finalizer credits, integration buckets and treasury allocations from round records and observed deliveries. It compares every source aggregate and all six categories against custody balances after each transition, including lazy expiry. Concurrent configurations settle in reverse order without sharing pots. A complete paid lifecycle and subsequent opening also execute after irreversible selector finalization.

These tests use controlled local time and deterministic Registry fixtures. They establish accounting and state transitions, not real BLS verification, elapsed live time, external Router delivery or target-chain execution.
