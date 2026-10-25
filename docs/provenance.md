# Source and licensing provenance

The reviewed sources are immutable Git revisions, not floating branch names.

| Source | Revision | Use |
| --- | --- | --- |
| EqualFiLabs/fiddy | `795425ef6a8830278b56b9052aa2271e92930eb3` | Diamond infrastructure and operating reference |
| EqualFiLabs/drand-registry | `118a94d2e447055d1a47d1a13488e887aaa4a822` | Registry consumer interface and real-verifier validation |
| EqualFiLabs/operator-fee-router | `a6afe541c6261f1febb2eaf0f4d68ef5aa16548e` | Router consumer interface and integration validation |
| OpenZeppelin/openzeppelin-contracts | `5fd1781b1454fd1ef8e722282f86f9293cacf256` | ERC-20 safety and full-precision arithmetic |
| foundry-rs/forge-std | `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b` | Test and script utilities |

Fiddy's Registry gitlink is `cdc760a9bf5bbbc1647d13e43b22858677dacad6`; Rooms deliberately uses the separately reviewed Registry revision above. The other three dependency pins match Fiddy's gitlinks. Registry itself pins the same forge-std revision.

The accepted Rooms compiler is Solidity 0.8.33, optimizer enabled at 200 runs, Osaka, without global via-IR. This explicitly approved change from Fiddy's 0.8.30 baseline permits direct compilation of the pinned Router (which requires 0.8.33). Fiddy-derived files and copied Registry validation sources require explicit pragma adaptation; dependency revisions remain unchanged. Record any source adaptations with the real-contract evidence.

Fiddy Solidity carries BUSL-1.1 notices and supplies no repository-level license parameters at this revision. Preserve those notices and identify copied infrastructure explicitly. Do not infer a permissive license or invent missing licensor parameters. Publication of this derivative is authorized by the repository owner; this delivery grants no additional production-use rights in upstream material. Production release must resolve any missing upstream license parameters with the rights holder.

The Router includes its own BUSL-1.1 license, EqualFi Labs licensor, no additional use grant, change date 2030-07-18, and MIT change license. Retain its complete license with the dependency. Registry's Solidity consumer interface is MIT. OpenZeppelin and forge-std retain their supplied licenses in their pinned dependencies. No wrapper license overrides dependency terms.

Local Registry integration generates test-only copies from the pinned Registry source, preserving all content and notices except its exact compiler pragma (`0.8.30` → `0.8.33`). `tools/prepare_registry.py` reads the pinned Git objects rather than an edited dependency worktree. These generated copies are excluded from version control and release assembly. The published Quicknet signature vector executes the actual verifier on the local Osaka EVM; this does not establish target-chain precompile availability or equality with a Registry compiled using 0.8.30. The pinned Router production contract is imported directly; its collection and authority remain local fixtures.
