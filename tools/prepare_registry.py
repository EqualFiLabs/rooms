#!/usr/bin/env python3
"""Generate test-only Registry sources with the accepted compiler pragma."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PIN = "118a94d2e447055d1a47d1a13488e887aaa4a822"


def prepare():
    source = ROOT / "lib/drand-registry"
    revision = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    if revision != PIN:
        raise ValueError(
            "Registry dependency revision does not match the reviewed baseline"
        )
    for path in sorted((source / "src").rglob("*.sol")):
        original = subprocess.check_output(
            ["git", "-C", str(source), "show", f"{PIN}:{path.relative_to(source)}"],
            text=True,
        )
        if original.count("pragma solidity 0.8.30;") != 1:
            raise ValueError("Expected exactly one upstream compiler pragma")
        target = ROOT / "test/generated/registry" / path.relative_to(source / "src")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            original.replace("pragma solidity 0.8.30;", "pragma solidity 0.8.33;")
        )


if __name__ == "__main__":
    prepare()
    print(
        "Registry test sources prepared from the pinned revision; pragma-only transformation."
    )
