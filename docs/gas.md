# Measured local execution costs

Solidity 0.8.33, Osaka, optimizer 200, Foundry commit `bdd1162b2c24814d2424ffad4f8c587827f1a6ab`. `forge test --match-test testMeasuredLifecycleAcrossRoomCountsAndAssetUnits -vv` measures gas around actual Diamond calls, with normal token transfers and the pinned production Router. The Registry is a chosen-room fixture for this measurement. Setup, funding, Registry cache preparation, transaction intrinsic gas and any real network fee are excluded. Measurements use a sequential in-test workload: the first case for each asset creates its revenue storage, later cases reuse it. These are measured workloads, not an isolated cold-transaction comparison or a reimbursement promise.

| Rooms | Asset decimals | Purchase | Settlement | Player claim | Expiry | Router contribution |
|---|---|---|---|---|---|---|
| 2 | 18 | 118631 | 314618 | 102193 | 66724 | 215117 |
| 8 | 18 | 118643 | 263331 | 102193 | 66726 | 146717 |
| 24 | 18 | 118645 | 263333 | 102193 | 66723 | 146717 |
| 2 | 6 | 118648 | 314636 | 102193 | 66725 | 215081 |
| 8 | 6 | 118650 | 263338 | 102193 | 66727 | 146681 |
| 24 | 6 | 118653 | 263340 | 102193 | 66729 | 146681 |

Purchase quantity is 20, following a paid 30-ticket opening. Both buyers select room zero, which wins; one buyer claims and the other prize expires. Room counts change the domain outcome selection but do not introduce winner-dependent iteration. The six-decimal and eighteen-decimal assets are explicit local supported-token fixtures.
