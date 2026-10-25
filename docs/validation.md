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
