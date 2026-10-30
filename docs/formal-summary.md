# Bounded formal evidence

The committed candidate `76d7999f667d3821f4df6547ff3177d2de7595ca` was compiled and checked in the approved remote verification environment. Solidity `0.8.33+commit.64118f21`, optimizer enabled with 200 runs, Osaka, and no via-IR match the local candidate. Halmos 0.3.3 ran with Foundry 1.7.1 (`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`). All 23 production runtime entries matched the candidate manifest before symbolic execution.

The SHA-256 of canonical compact, key-sorted JSON for the manifest's `sourceSHA256` map is `4a9878dae0bfb20cbe0d9b0fb7b79d7d8edfd69a697c5393c57a4ef9c18021e8`; for its `contracts` map, including runtime Keccak hashes and selectors, it is `4942498aa47daec1545c3afbe401a64b5055758a8fc861edcdeb7c295cd86bdb`. These identify compiled source/runtime inputs, not deployed contracts.

| Property | Executed bound and assumptions | Result |
|---|---|---|
| Shared guard and finalization latch | Fresh zero storage; initialize, enter, exit, set authority and disable cuts; attempted empty cut | Passed, one explored path |
| Per-ticket conservation, dust and holdings partition | Pot 0–255; exactly three tickets; partition 0–3; actual arithmetic library | Passed, 11 paths |
| Pending-pot attachment and isolation | Pot 0–2^64−1; one fresh enabled local configuration, no Operator share, one capacity slot, concrete time; actual opening library, second reservation rejected | Passed, three paths |
| Populated and empty outcomes | Pot 0–65,535; exactly three winning tickets for populated branch; fresh configuration/asset accounting, settlement time 100 | Passed, seven paths; includes fixed claim deadline and second asset non-mutation |
| Wider allocation and epoch arithmetic | Symbolic parameters, time-bounded attempts | Incomplete: timed out |
| Common settlement and expiry through delegatecall | Synthetic component storage and low-level dispatch | Incomplete: model/dispatch mismatch or all paths reverted; no proof claimed |

Each completed symbolic campaign used loop bound four, one solver thread, 10-second assertion-query and one-second branch-query limits, and panic checking for every panic code. The initialization/latch campaign used a 20-second assertion-query limit. A per-property wall-clock limit bounded resource use. Bounds are deliberate restrictions; these results do not establish full-width, arbitrary-configuration or whole-protocol correctness.

Formal harnesses, query files, witnesses and raw results remain outside version control. Fresh synthetic component storage assumes disjoint namespace hashes, ordinary EVM arithmetic and successful initialization prerequisites. Token transfers, Registry cryptography/liveness, Router behavior, sequencer honesty, public claim delivery and the complete consumer lifecycle are outside these proofs. Concrete EVM witnesses reproduced the modeled setup for pending attachment, populated payout and expiry; the expiry witness passed, so the symbolic discrepancy remains unproven rather than a reported protocol counterexample.

Actual-Diamond tests, full-width fuzz properties and stateful source-ledger invariants provide separate evidence for properties outside the completed formal bounds. No timeout, unknown, all-reverted campaign or model discrepancy is counted as a passing proof. Later changes to production source require fresh provenance comparison and affected evidence; documentation and additional tests alone do not change compiled production inputs.

The final code candidate `9af964113ed530364884d790b16233924b531760` has identical `src/` content to the proven checkpoint; source comparison confirms that these restricted production-library results retain their original inputs and bounds. PR 15 adds deployment assembly under `script/`, which was tested through the actual Diamond and external timelock but is outside these formal campaigns. The final manifest source map additionally binds that script; its 23 production runtime entries remain identical to the proven checkpoint. No broader proof is implied.
