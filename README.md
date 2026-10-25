# Rooms

Rooms is an EqualFi Labs game with one custody Diamond, concurrent ERC-20 configurations and 2–24 rooms per round. Sales close on sellout or the original deadline. Ticket prices rise across four epochs at 1.00x, 1.25x, 1.50x and 1.75x; all tickets have equal prize weight. A committed Quicknet beacon selects a room. Empty outcomes and payout dust roll into the next round of the same configuration. Player prizes expire 30 days after settlement.

The implementation uses Solidity **0.8.33**, Osaka and 200 optimizer runs. Production assets, prices, supplies and authority addresses remain unset. The Robinhood Testnet rehearsal is **prepared but unexecuted**; no signing or broadcast is part of this delivery.

## Build and validate

Clone with recursive submodules. Use the Foundry revision pinned in the validation workflow, then run:

```sh
python3 tools/prepare_registry.py
forge fmt --check
forge build --sizes
FOUNDRY_PROFILE=ci forge test
forge lint src script --severity high -D warnings
python3 tools/build_manifest.py candidate-manifest.json
python3 -m unittest discover -s tools/tests -v
```

The Registry helper generates ignored, test-only pragma-adapted sources from pinned Git objects. CI runs the same gates for feature-branch pushes and PRs, including PRs targeting feature branches. It uploads the source/runtime/selector/event/storage-schema candidate manifest. The CI profile uses 1,024 fuzz runs and 256 invariant sequences at depth 64, failing on unexpected handler reverts.

For a local rehearsal without signing, run `python3 tools/rehearse.py --output rehearsal-result.json`. [Rehearsal preparation](docs/rehearsal.md) explains assembly, supplied-observation preflight, evidence validation and future live prerequisites.

## Specification and evidence

- [Requirements](requirements.md), [design](design.md), and [completed task slices](tasks.md)
- [Protocol operation and direct-call commands](docs/protocol.md)
- [Configuration and authority policy](docs/configuration.md), [source and licensing provenance](docs/provenance.md)
- [Acceptance map](docs/acceptance.md), [local validation](docs/validation.md), [bounded formal evidence](docs/formal-summary.md), and [measured gas](docs/gas.md)
- [Review stack and final handoff](docs/handoff.md)

Occupancy and holdings are public. Higher late-entry prices do not eliminate strategic dilution. Canonical exact-transfer, non-rebasing assets, external Registry/Router behavior, and sequencer honesty remain explicit assumptions. Selector finalization preserves operational governance and external dependencies. Read the specification and evidence limits before choosing launch inputs.
