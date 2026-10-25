# Candidate acceptance and evidence map

This checkpoint reconciles all numbered requirements against the cumulative source and local evidence. Ranges below include every acceptance criterion in that requirement. A passing test is evidence under its stated fixtures, not an unconditional guarantee or a target-chain rehearsal.

| Criteria | Implementation and local evidence | Boundary |
|---|---|---|
| 1.1–1.6 | Fiddy-derived shell/cut/loupe, independent namespaces; Diamond and initializer suites; provenance notices | Existing Fiddy deployment is not Rooms evidence |
| 2.1–2.8 | Configuration validator, immutable snapshots; configuration, epoch, commitment and expiry suites | Production terms remain unset |
| 3.1–3.8 | Permanent known assets, mutable approval, nominal SafeERC20; governance, opening, claim, revenue and safe-token tests | Canonical exact-transfer, non-rebasing behavior and issuer controls are operational assumptions |
| 4.1–4.7 | Paid atomic opening, active pointers/capacity; opening, commitments, settlement integration and invariant suites | No external scheduler needed |
| 5.1–5.7 | Counted entries, rounded unit prices and maximum payment; purchase, opening integration, claims and math properties | No wallet cap, ticket transfer, or outcome guarantee |
| 6.1–6.7 | Original/selected commitments and atomic sellout; commitment, selected-target and real-vector suites | Honest sequencer/timestamp progression; future target-chain client checks remain required |
| 7.1–7.8 | Complete accounting-only settlement; proof/cache/domain/freshness and complete outcome tests | Registry liveness required indefinitely; no fallback/refund |
| 8.1–8.8 | Full-width aggregate allocation, treasury-funded tip; math fuzzing, source-ledger reference and event reconstruction | Token tip does not promise gas reimbursement |
| 9.1–9.8 | Configuration pending pots and successor attachment; repeated-empty, reverse-order concurrent and invariant coverage | A disabled configuration's pot can remain inactive |
| 10.1–10.7 | One per-ticket payout and same-configuration remainder; dust-only, partition, claim-order and preview coverage | No participant-dependent state transition loops |
| 11.1–11.7 | One-shot CEI claims, shared guard, caller-selected valid receiver; claims/finalizer and false-return/retry suites | Token failures preserve liabilities but can delay delivery |
| 12.1–12.7 | Fixed 30-day deadline, lazy obligation, one-shot reclassification; boundary, partial/all/zero and admission tests | Controlled local time; no live 30-day observation |
| 13.1–13.7 | Historical integration buckets, readiness, temporary allowance; revenue tests and actual Router/Operator claim | Actual Router with fixture collection/authority |
| 14.1–14.8 | Capped treasury, known-only six-category surplus, native rejection/recovery; donation/shortfall/native tests | Unsupported token balance mutation is outside solvency assumptions |
| 15.1–15.6 | Guardian pause and authority unpause; governance, opening and exit/lifecycle tests | Pausing does not change deadlines or targets |
| 16.1–16.7 | Authority cuts, atomic initialization, permanent latch; Diamond/governance and continuing-play tests | Concrete external timelock roles/delay are launch inputs; assembly/preflight follows |
| 17.1–17.5 | Append-only endpoints and snapshots; governance, selected-target and historical Router tests | Registry crypto remains outside Rooms production code |
| 18.1–18.8 | Six categories, source buckets and supported-token custody; deterministic and randomized two-asset reference reconciliation | Donations are separately modeled; no synthetic consumer storage patching |
| 19.1–19.7 | Bounded public views, conditional previews and economic logs; quote/payment/claim/preview/reconstruction tests | Public reads need no privileged service; no frontend included |
| 20.1–20.5 | Shared initialized guard, CEI, atomic failures; cross-facet callbacks, proof and token/receiver/Router retry tests | External integrations remain trust/liveness dependencies |
| 21.1–21.7 | Requirements/design trust and game-strategy disclosures; equal-weight price/claim evidence | Source, mocked, real-contract local, formal, fork and live evidence remain distinct |
| 22.1–22.8 | Subtask commits, incremental PRs, pinned compiler/dependencies, CI and manifests | Bounded formal, rehearsal preparation and final handoff follow; live execution is unexecuted |

At the preceding committed validation checkpoint, CI passed 92 tests and 256 invariant sequences of depth 64 (16,384 calls, zero unexpected reverts), plus formatting, size-aware compilation, high-severity lint and manifest generation. This checkpoint adds explicit ERC-20 false-return failure/retry coverage. CI owns the cumulative release gates; the changed local consumer lifecycle is also executed directly.

The published Quicknet vector is cryptographically verified by the pragma-adapted pinned Registry in a local Osaka EVM, and its randomness passes through the Diamond's actual domain separator. The production Router is bootstrapped normally against fixture collection/activation contracts, receives real fixture tokens and pays an Operator. Chosen-room tests and randomized handlers use separately labeled Registry/Router fixtures. No fork, target-chain deployment, live signature, transaction broadcast, real authority-role confirmation, or production configuration approval is claimed. Formal status is reported separately when executed.
