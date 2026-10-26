#!/usr/bin/env python3
"""Emit deterministic compiler, dependency, selector and runtime provenance."""
from pathlib import Path
import hashlib
import os
import json
import re
import subprocess
import sys
import tomllib


def require(condition, message="Invalid build provenance"):
    if not condition:
        raise ValueError(message)


ROOT = Path(__file__).resolve().parents[1]
PINS = {
    "forge-std": "bf647bd6046f2f7da30d0c2bf435e5c76a780c1b",
    "openzeppelin-contracts": "5fd1781b1454fd1ef8e722282f86f9293cacf256",
    "drand-registry": "118a94d2e447055d1a47d1a13488e887aaa4a822",
    "operator-fee-router": "a6afe541c6261f1febb2eaf0f4d68ef5aa16548e",
}


def command(*args, stdin=None):
    return subprocess.check_output(
        args,
        cwd=ROOT,
        text=True,
        input=stdin,
        env=dict(os.environ, FOUNDRY_DISABLE_NIGHTLY_WARNING="1"),
    ).strip()


def verify_sources(metadata, cache=None):
    cache = {} if cache is None else cache
    for source, record in metadata["sources"].items():
        require((ROOT / source).is_file(), "Missing imported source")
        if source not in cache:
            cache[source] = command(
                "cast", "keccak", stdin="0x" + (ROOT / source).read_bytes().hex()
            )
        require(cache[source] == record["keccak256"], "Stale imported source artifact")


def source_artifacts(source, cache=None):
    """Resolve declared compiler targets, including contracts in .s.sol files."""
    relative = str(source.relative_to(ROOT))
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", source.read_text(), flags=re.S)
    names = re.findall(
        r"^\s*(?:abstract\s+)?(?:contract|interface|library)\s+(\w+)\b", text, re.M
    )
    for name in names:
        artifact = ROOT / "out" / source.name / f"{name}.json"
        require(artifact.is_file(), f"Missing artifact for {relative}:{name}")
        data = json.loads(artifact.read_text())
        metadata = data["metadata"]
        settings = metadata["settings"]
        require(
            settings["compilationTarget"] == {relative: name},
            "Mismatched compilation target",
        )
        require(relative in metadata["sources"], "Missing compilation target source")
        verify_sources(metadata, cache)
        require(metadata["compiler"]["version"] == "0.8.33+commit.64118f21")
        require(not settings.get("viaIR", False))
        require(
            settings["evmVersion"] == "osaka"
            and settings["optimizer"] == {"enabled": True, "runs": 200}
        )
        yield f"{relative}:{name}", data


def build():
    config = tomllib.loads((ROOT / "foundry.toml").read_text())["profile"]["default"]
    require(
        (
            config["solc"],
            config["evm_version"],
            config["optimizer"],
            config["optimizer_runs"],
        )
        == ("0.8.33", "osaka", True, 200)
    )
    require(not config.get("via_ir", False))
    for name, pin in PINS.items():
        require(command("git", "-C", f"lib/{name}", "rev-parse", "HEAD") == pin)
        require(
            not command(
                "git",
                "-C",
                f"lib/{name}",
                "status",
                "--porcelain",
                "--untracked-files=no",
            )
        )
    files = sorted((ROOT / "src").rglob("*.sol")) + sorted(
        (ROOT / "script").rglob("*.sol")
    )
    sources = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in files
    }
    contracts = {}
    script_contracts = {}
    source_cache = {}
    event_abis = {}
    for p in files:
        for key, data in source_artifacts(p, source_cache):
            runtime = data["deployedBytecode"]["object"]
            if runtime in ("", "0x"):
                continue
            if "/facets/" in str(p):
                for item in data["abi"]:
                    if item["type"] == "event":
                        require(
                            item["name"] not in event_abis
                            or event_abis[item["name"]] == item,
                            "Ambiguous event ABI",
                        )
                        event_abis[item["name"]] = item
            inventory = (
                script_contracts if p.is_relative_to(ROOT / "script") else contracts
            )
            inventory[key] = {
                "runtimeKeccak256": command("cast", "keccak", runtime),
                "runtimeBytes": len(runtime.removeprefix("0x")) // 2,
                "selectors": data["methodIdentifiers"],
            }
    require("src/RoomsDiamond.sol:RoomsDiamond" in contracts)
    storage = {}
    for name in ("LibRoomsStorage", "LibDiamond"):
        text = (ROOT / "src/libraries" / f"{name}.sol").read_text()
        domains = re.findall('keccak256\\("([^"]+)"\\)', text)
        structs = re.findall("struct \\w+\\s*\\{[^}]+\\}", text)
        storage[name] = {
            "namespaces": {
                domain: command("cast", "keccak", domain) for domain in domains
            },
            "orderedSchemaSHA256": hashlib.sha256(
                "\n".join(structs).encode()
            ).hexdigest(),
        }
    storage["valueTypesSHA256"] = hashlib.sha256(
        (ROOT / "src/shared/Types.sol").read_bytes()
    ).hexdigest()
    assembly = {}
    for key, contract in contracts.items():
        if "/facets/" in key:
            for signature, selector in contract["selectors"].items():
                require(selector not in assembly, f"Selector collision: {signature}")
                assembly[selector] = {"contract": key, "signature": signature}
    require(len(assembly) == 51)
    return {
        "schema": 1,
        "eventABIs": event_abis,
        "storageSchemas": storage,
        "selectorAssembly": assembly,
        "sourceCommit": command("git", "rev-parse", "HEAD"),
        "compiler": "0.8.33+commit.64118f21",
        "evmVersion": "osaka",
        "optimizerRuns": 200,
        "viaIR": False,
        "dependencies": PINS,
        "sourceSHA256": sources,
        "contracts": contracts,
        "scriptContracts": script_contracts,
    }


if __name__ == "__main__":
    result = json.dumps(build(), sort_keys=True, indent=2) + "\n"
    if len(sys.argv) == 2:
        Path(sys.argv[1]).write_text(result)
    else:
        print(result, end="")
