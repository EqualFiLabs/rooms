# Review stack and operational handoff

The final code candidate is `9af964113ed530364884d790b16233924b531760`, the head of [PR 15](https://github.com/EqualFiLabs/rooms/pull/15). PR 16 contains documentation and task 17's final checkpoint only. Production contracts and executable tooling are unchanged in PR 16.

## Review stack

Each PR contains its parent task, with commit slices for subtasks. Task 17 is included in PR 16. Each PR targets its predecessor, so its diff is incremental. Review order is 1 through 16. All sixteen are open and unmerged, with no auto-merge enabled. The default branch retains only the authorized README root commit `c4dfe32eb7ba621e19eaeaad75c4958d9222e5bc`. Current PR metadata and checks are available at the links below.

| PR | Deliverable | Head branch | Base branch |
|---|---|---|---|
| [1](https://github.com/EqualFiLabs/rooms/pull/1) | Specification and inputs | `feat/rooms-01` | `main` |
| [2](https://github.com/EqualFiLabs/rooms/pull/2) | Diamond and storage | `feat/rooms-02` | `feat/rooms-01` |
| [3](https://github.com/EqualFiLabs/rooms/pull/3) | Governance | `feat/rooms-03` | `feat/rooms-02` |
| [4](https://github.com/EqualFiLabs/rooms/pull/4) | Purchases and commitments | `feat/rooms-04` | `feat/rooms-03` |
| [5](https://github.com/EqualFiLabs/rooms/pull/5) | Opening checkpoint | `feat/rooms-05` | `feat/rooms-04` |
| [6](https://github.com/EqualFiLabs/rooms/pull/6) | Settlement components | `feat/rooms-06` | `feat/rooms-05` |
| [7](https://github.com/EqualFiLabs/rooms/pull/7) | Rollover and prizes | `feat/rooms-07` | `feat/rooms-06` |
| [8](https://github.com/EqualFiLabs/rooms/pull/8) | Claims and expiry | `feat/rooms-08` | `feat/rooms-07` |
| [9](https://github.com/EqualFiLabs/rooms/pull/9) | Settlement checkpoint | `feat/rooms-09` | `feat/rooms-08` |
| [10](https://github.com/EqualFiLabs/rooms/pull/10) | Revenue delivery | `feat/rooms-10` | `feat/rooms-09` |
| [11](https://github.com/EqualFiLabs/rooms/pull/11) | Public interface | `feat/rooms-11` | `feat/rooms-10` |
| [12](https://github.com/EqualFiLabs/rooms/pull/12) | Complete local validation | `feat/rooms-12` | `feat/rooms-11` |
| [13](https://github.com/EqualFiLabs/rooms/pull/13) | Candidate checkpoint | `feat/rooms-13` | `feat/rooms-12` |
| [14](https://github.com/EqualFiLabs/rooms/pull/14) | Formal properties and candidate review | `feat/rooms-14` | `feat/rooms-13` |
| [15](https://github.com/EqualFiLabs/rooms/pull/15) | Rehearsal preparation: final code | `feat/rooms-15` | `feat/rooms-14` |
| [16](https://github.com/EqualFiLabs/rooms/pull/16) | Documentation and final handoff | `feat/rooms-16` | `feat/rooms-15` |

## Reproducible candidate

Solidity `0.8.33+commit.64118f21`, Osaka, optimizer 200, no global via-IR; Foundry `bdd1162b2c24814d2424ffad4f8c587827f1a6ab`. Exact dependencies and applicable notices are in [provenance](provenance.md). Production assets, prices, supplies, durations, delays, reward rate, capacity, configurations and authority/guardian/treasury addresses remain unset; fixtures are explicitly local. Initial launch economics must be 50/20/30 before the treasury-funded tip.

Build the manifest using the [README commands](../README.md). It binds compiler/dependencies, source hashes, 23 production runtime entries, 51 selectors and their facet owners, event ABIs and namespace/ordered-schema digests. `sourceCommit` identifies the checkout used to generate it; compare source maps and runtime identities when documentation-only commits differ. For the final code candidate, SHA-256 of each canonical compact key-sorted JSON map is:

| Manifest map | SHA-256 |
|---|---|
| `sourceSHA256` | `ea7f66d62423d6dafe65e784e7c1eea84b965024d3b77f87553170bf59a36a44` |
| `contracts` | `4942498aa47daec1545c3afbe401a64b5055758a8fc861edcdeb7c295cd86bdb` |
| `selectorAssembly` | `4579833bf15bfe9db1c52f45f7860019076ec76856c7639074b12fc12095d44d` |
| `storageSchemas` | `86a84486b79b08a30464b59fc62d20089b2a73273a769aeb8b63a6ee010bc803` |
| `eventABIs` | `13436c0239fde45336f211a7d8b6e37ec68f3c60103edfa0fa293fa202ff6ffc` |

Source hashes include the assembly script. Runtime identities describe candidate code, not deployed contracts. Schema digests do not establish upgrade safety automatically. Independently review storage compatibility, compiler/client constraints and installed selector identities before any activation.

## Validation delivered

The code candidate's [push CI](https://github.com/EqualFiLabs/rooms/actions/runs/40222608946) and [PR CI](https://github.com/EqualFiLabs/rooms/actions/runs/40222619828) both passed 96 Solidity tests across 26 suites, ten Python tooling tests, formatting, size-aware compilation, high-severity lint and deterministic manifest generation. Fuzz runs are 1,024; invariants are 256 sequences at depth 64, with 16,384 calls and zero unexpected reverts. Every published implementation PR through PR 15 passed both applicable push and PR gates; the initial specification-only PR predates the workflow. PR 16 runs the same gates; inspect its [checks](https://github.com/EqualFiLabs/rooms/pull/16/checks) for final documentation-head status.

The local rehearsal passed 29 tests across eight named suites at that exact code commit, without signing or broadcast. Actual-Diamond tests cover both sales cutoffs, epoch pricing, fixed player expiry, repeated rollover, reference-ledger conservation, failure/retry, revenue delivery and continued operation after selector finalization. Real Registry cryptographic-vector and Router implementation tests are separate from deterministic chosen-outcome fixtures. Both supplied-observation and receipt validator CLIs pass explicit fixture inputs; they do not authenticate chain evidence themselves. Details and limitations are in [validation](validation.md) and the [acceptance map](acceptance.md).

Four restricted remote symbolic properties completed; wider campaigns timed out or had model/dispatch limitations and remain incomplete. The production source/runtime inputs are unchanged from that checkpoint. The deployment assembly is covered by concrete tests, outside those proofs. The [formal summary](formal-summary.md) records exact source/runtime bindings, compiler/tools, bounds and assumptions; private harnesses and raw outputs are excluded from version control.

## Remaining operational boundaries

Robinhood Testnet rehearsal execution and live evidence are **prepared but unexecuted**. No deployment, transaction signing, broadcasting, live proof acquisition, live role confirmation, target-client execution or irreversible finalization has occurred. Controlled local time proves boundary behavior; it is not a live 30-day observation. No fork or production deployment is claimed.

Before separately authorized live work, the release owner must supply complete launch inputs, resolve applicable upstream production license parameters, approve canonical exact-transfer/non-rebasing assets without aliases, verify target-client Osaka behavior, and independently establish Registry/Router code identities and readiness. Verify the external timelock's code, delay, complete role history, proposers, executors, administrators and cancellers. Boolean fixture attestations and listed `hasRole` observations do not replace that review. Follow [rehearsal preparation](rehearsal.md) for the future live sequence and evidence collection.

For operation and direct ABI commands, use [protocol operation](protocol.md). Settlement and exits remain permissionless while paused or admission is removed; player claims still expire after 30 days. Pending configuration pots, finalizer credits and Operator liabilities do not expire. Historical Operator buckets cannot be redirected. Indefinite Registry failure, issuer controls, disabled-configuration pots and sequencer behavior remain explicit risks. Public occupancy permits intentional late-entry dilution despite higher epoch prices.

Selector finalization fixes installed code but preserves operational governance and external dependencies. Any later live activation or finalization requires its own authorization and verified inputs. No PR is merged as part of this handoff.
