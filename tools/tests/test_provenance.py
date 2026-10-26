import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from tools.build_manifest import source_artifacts, verify_sources

ROOT = Path(__file__).resolve().parents[2]


class ProvenanceTest(unittest.TestCase):
    def test_script_runtime_has_separate_manifest_inventory(self):
        manifest = json.loads((ROOT / "candidate-manifest.json").read_text())
        key = "script/DeployRooms.s.sol:DeployRooms"
        self.assertEqual(set(manifest["scriptContracts"]), {key})
        self.assertGreater(manifest["scriptContracts"][key]["runtimeBytes"], 0)
        self.assertNotIn(key, manifest["contracts"])
        self.assertEqual(len(manifest["contracts"]), 23)
        self.assertEqual(len(manifest["selectorAssembly"]), 51)

    def test_script_contract_uses_compiler_target_name(self):
        artifacts = list(source_artifacts(ROOT / "script/DeployRooms.s.sol"))
        self.assertEqual(
            [key for key, _ in artifacts], ["script/DeployRooms.s.sol:DeployRooms"]
        )
        self.assertNotIn(artifacts[0][1]["deployedBytecode"]["object"], ("", "0x"))

    def test_missing_script_artifact_is_rejected(self):
        with patch("tools.build_manifest.Path.is_file", return_value=False):
            with self.assertRaisesRegex(ValueError, "Missing artifact.*DeployRooms"):
                list(source_artifacts(ROOT / "script/DeployRooms.s.sol"))

    def test_script_metadata_target_and_imports_are_checked(self):
        data = json.loads((ROOT / "out/DeployRooms.s.sol/DeployRooms.json").read_text())
        wrong_target = copy.deepcopy(data)
        wrong_target["metadata"]["settings"]["compilationTarget"] = {
            "script/DeployRooms.s.sol": "Other"
        }
        with patch("tools.build_manifest.json.loads", return_value=wrong_target):
            with self.assertRaisesRegex(ValueError, "Mismatched compilation target"):
                list(source_artifacts(ROOT / "script/DeployRooms.s.sol"))
        data["metadata"]["sources"]["script/DeployRooms.s.sol"]["keccak256"] = (
            "0x" + "00" * 32
        )
        with patch("tools.build_manifest.json.loads", return_value=data):
            with self.assertRaisesRegex(ValueError, "Stale imported source"):
                list(source_artifacts(ROOT / "script/DeployRooms.s.sol"))

    def test_transitive_source_identity(self):
        metadata = json.loads(
            (ROOT / "out/RoomsFacet.sol/RoomsFacet.json").read_text()
        )["metadata"]
        verify_sources(metadata)
        stale = copy.deepcopy(metadata)
        imported = next(
            k for k in stale["sources"] if k.endswith("/LibRoomsPurchase.sol")
        )
        stale["sources"][imported]["keccak256"] = "0x" + "00" * 32
        with self.assertRaisesRegex(ValueError, "Stale imported source"):
            verify_sources(stale)
