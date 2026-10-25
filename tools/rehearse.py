#!/usr/bin/env python3
"""Run the local rehearsal. There is deliberately no live or broadcast mode."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from build_manifest import build, ROOT
from preflight import digest, require

SUITES = [
    "RoomsAssemblyTest",
    "RoomsEndToEndTest",
    "RoomsOpeningIntegrationTest",
    "RoomsSettlementIntegrationTest",
    "RoomsCommitmentsTest",
    "RoomsClaimsTest",
    "RoomsExpiryTest",
    "RoomsOperatorRevenueTest",
]


def run():
    env = dict(os.environ, FOUNDRY_DISABLE_NIGHTLY_WARNING="1")
    subprocess.run(
        [sys.executable, "tools/prepare_registry.py"],
        cwd=ROOT,
        env=env,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["forge", "build"], cwd=ROOT, env=env, check=True, capture_output=True
    )
    result = subprocess.run(
        ["forge", "test", "--json", "--match-contract", "^(" + "|".join(SUITES) + ")$"],
        cwd=ROOT,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    suites = json.loads(result.stdout)
    require(
        {key.split(":")[-1] for key in suites} == set(SUITES), "missing rehearsal suite"
    )
    tests = {}
    for suite, data in suites.items():
        require(bool(data["test_results"]), "empty suite")
        for name, outcome in data["test_results"].items():
            require(outcome["status"] == "Success", "failed or skipped rehearsal test")
            tests[suite.split(":")[-1] + "." + name] = "passed"
    manifest = build()
    (ROOT / "candidate-manifest.json").write_text(
        json.dumps(manifest, sort_keys=True, indent=2) + "\n"
    )
    return dict(
        schema=1,
        mode="local",
        liveExecution="prepared but unexecuted",
        signing=False,
        broadcasting=False,
        sourceCommit=manifest["sourceCommit"],
        manifestDigest=digest(manifest),
        tests=tests,
        evidence={
            "registry": "pinned published Quicknet vector in local EVM",
            "router": "real implementation with local collection fixtures",
            "outcomes": "deterministic fixture branch coverage",
            "expiry": "controlled local time",
            "authority": "local external timelock",
        },
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="rehearsal-result.json")
    args = parser.parse_args()
    try:
        result = run()
    except (subprocess.CalledProcessError, ValueError, KeyError) as error:
        parser.exit(
            1,
            f"Local rehearsal failed ({type(error).__name__}); no signing or broadcasting performed.\n",
        )
    Path(args.output).write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
    print(
        f"Local rehearsal passed {len(result['tests'])} tests. Live execution: prepared but unexecuted."
    )


if __name__ == "__main__":
    main()
