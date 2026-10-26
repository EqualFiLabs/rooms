import contextlib
import io
import json
import subprocess
import unittest
from unittest.mock import patch
from tools.rehearse import failure_details, main


class RehearsalDiagnosticsTest(unittest.TestCase):
    def test_compiler_diagnostics_accept_bytes_and_remain_bounded(self):
        error = subprocess.CalledProcessError(
            1,
            ["forge", "build"],
            stderr=b"Compiler error: invalid type\n" + b"x" * 5000,
        )
        details = failure_details(error)
        self.assertIn("Compiler error: invalid type", details)
        self.assertIn("diagnostics truncated", details)
        self.assertLess(len(details), 4100)

    def test_failed_test_name_and_reason_survive_large_success_output(self):
        suites = {
            "test:Suite": {
                "test_results": {
                    "testSuccess()": {"status": "Success", "logs": "x" * 5000},
                    "testPayment()": {
                        "status": "Failure",
                        "reason": "assertion failed: 2 != 3",
                    },
                }
            }
        }
        error = subprocess.CalledProcessError(
            1, ["forge", "test"], output=json.dumps(suites), stderr="warning\n" * 1000
        )
        details = failure_details(error)
        self.assertIn("Suite.testPayment()", details)
        self.assertIn("assertion failed: 2 != 3", details)
        self.assertNotIn("testSuccess", details)

    def test_non_json_stdout_is_preserved(self):
        error = subprocess.CalledProcessError(
            1, ["forge", "test"], output="invalid test filter"
        )
        self.assertIn("invalid test filter", failure_details(error))

    def test_cli_reports_validation_reason_and_exits_unsuccessfully(self):
        stderr = io.StringIO()
        with patch("sys.argv", ["rehearse.py"]), patch(
            "tools.rehearse.run", side_effect=ValueError("missing rehearsal suite")
        ), contextlib.redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as error:
                main()
        self.assertEqual(error.exception.code, 1)
        self.assertIn("missing rehearsal suite", stderr.getvalue())
