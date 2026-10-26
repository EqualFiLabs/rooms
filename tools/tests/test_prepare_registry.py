from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from tools import prepare_registry


class RegistryPreparationTest(unittest.TestCase):
    def prepared_module(self, optimization, root):
        script = Path(prepare_registry.__file__)
        namespace = {"__file__": str(script), "__name__": "registry_fixture"}
        exec(
            compile(script.read_text(), str(script), "exec", optimize=optimization),
            namespace,
        )
        namespace["ROOT"] = root
        return namespace

    def test_revision_and_pragma_guards_survive_optimization(self):
        for optimization in (0, 1):
            for original in ("pragma solidity 0.8.33;", "pragma solidity 0.8.30;" * 2):
                with self.subTest(
                    optimization=optimization, original=original
                ), TemporaryDirectory() as directory:
                    root = Path(directory)
                    source = root / "lib/drand-registry/src/Registry.sol"
                    source.parent.mkdir(parents=True)
                    source.write_text("source inventory fixture")
                    module = self.prepared_module(optimization, root)
                    with patch(
                        "subprocess.check_output", return_value="unexpected revision"
                    ):
                        with self.assertRaisesRegex(ValueError, "dependency revision"):
                            module["prepare"]()
                    with patch(
                        "subprocess.check_output", side_effect=[module["PIN"], original]
                    ):
                        with self.assertRaisesRegex(
                            ValueError, "exactly one upstream compiler pragma"
                        ):
                            module["prepare"]()
                    self.assertFalse((root / "test/generated").exists())

    def test_generation_preserves_everything_except_the_compiler_pragma(self):
        original = "// upstream notice\npragma solidity 0.8.30;\ncontract Registry {}\n"
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "lib/drand-registry/src/Registry.sol"
            source.parent.mkdir(parents=True)
            source.write_text("source inventory fixture")
            module = self.prepared_module(1, root)
            with patch(
                "subprocess.check_output", side_effect=[module["PIN"], original]
            ):
                module["prepare"]()
            generated = root / "test/generated/registry/Registry.sol"
            self.assertEqual(
                generated.read_text(), original.replace("0.8.30", "0.8.33")
            )
