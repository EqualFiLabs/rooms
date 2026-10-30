# Configuration and authority inputs

Production inputs remain unset. No test value is a launch recommendation or a deployed address. A release manifest must supply chain ID, canonical supported assets, base-unit prices, supplies, durations, delays, purchase limits, tip rate, capacity, initial configurations, Registry and Router versions, authority, guardian, and treasury receiver. Initial economics are 5000/2000/3000 BPS before the treasury-funded tip.

Deterministic local fixtures deploy their own exact-transfer ERC-20 contracts with 18 and 6 decimals. The baseline uses one whole token as base price, 100 tickets across all rooms, 400-second sales, 30-second randomness delay, no additional purchase cap, 500 BPS of gross treasury as finalizer tip, four active rounds, and two rooms. Additional fixtures exercise 3, 7, 8 and 24 rooms, four-second and non-divisible durations, coarse base units, and full-width amounts. None of these values is embedded as a production default.

The authority is an external timelock, not a Rooms timelock implementation. Local tests may use a designated test authority and OpenZeppelin TimelockController for role/delay coverage. Before live use, preflight must verify the supplied timelock code, minimum delay, proposers, executors, administrators, and custody expectations. Unverified roles or delays fail release validation. Guardian can pause only; authority unpauses. Treasury receiver is independent of authority. Configuration governance survives irreversible selector finalization.

Only canonical exact-transfer, non-rebasing assets are admitted. Issuer freezes, aliases, upgrades and balance behavior remain admission assumptions; nominal SafeERC20 transfers do not measure balance deltas. Removing approval blocks new exposure while preserving historical settlement, claims and revenue delivery.

The rehearsal deliverable is local preparation and evidence validation. No live transactions, signatures, broadcasts or irreversible finalization are authorized by this package.
