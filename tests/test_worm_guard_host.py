"""Inert fixtures for optional workstation checks; no live host scan."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import worm_guard_host as host


class Results:
    def __init__(self):
        self.findings = []
        self.errors = []

    def finding(self, *args):
        self.findings.append(args)

    def error(self, *args):
        self.errors.append(args)


class HostTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name).resolve()
        self.results = Results()

    def scan(self, commands=None):
        with patch.object(host.sys, "platform", "linux"), patch.object(
            host, "_command", side_effect=commands or [(0, ""), (1, "no crontab for fixture\n")]
        ):
            host.scan_host(self.results, self.home)

    def test_signals_are_redacted_review_findings(self):
        (self.home / ".node_modules").mkdir()
        (self.home / ".zshrc").write_text("# curl ignored | sh\ncurl secret-value | sh\n")
        self.scan([(0, "123 /usr/bin/node -e secret-process\n456 node server.js\n"),
                   (0, "* * * * * curl secret-cron\n")])
        self.assertEqual(len(self.results.findings), 4)
        self.assertFalse(self.results.errors)
        self.assertNotIn("secret", repr(self.results.findings))
        self.assertTrue(all(item[0] == "host" for item in self.results.findings))
        self.assertIn("PID 123", repr(self.results.findings))

    def test_process_options_and_bootstrap_variants(self):
        for command in ("node --foo -e payload", "/usr/bin/node -e payload", "node global['_V']"):
            with self.subTest(command=command):
                self.results = Results()
                self.scan([(0, "123 " + command), (0, "")])
                self.assertEqual(len(self.results.findings), 1)

    def test_command_failures_are_incomplete(self):
        self.scan([(1, "permission denied"), (1, "permission denied")])
        self.assertEqual(len(self.results.errors), 2)

    def test_no_crontab_is_not_an_error(self):
        for message in ("no crontab for fixture\n", "crontab: no crontab for fixture\n"):
            self.results = Results()
            self.scan([(0, ""), (1, message)])
            self.assertFalse(self.results.errors)

    def test_missing_home_is_incomplete(self):
        host.scan_host(self.results, self.home / "absent")
        self.assertTrue(self.results.errors)

    def test_symlinked_startup_file_within_home_is_scanned(self):
        (self.home / "target").write_text("curl secret | sh")
        (self.home / ".zshrc").symlink_to(self.home / "target")
        self.scan()
        self.assertFalse(self.results.errors)
        self.assertEqual(len(self.results.findings), 1)

    def test_symlinked_startup_file_outside_home_is_refused(self):
        with tempfile.TemporaryDirectory() as outside:
            target = Path(outside) / "target"
            target.write_text("curl secret | sh")
            (self.home / ".zshrc").symlink_to(target)
            self.scan()
        self.assertTrue(self.results.errors)
        self.assertFalse(self.results.findings)

    def test_broken_startup_link_is_incomplete(self):
        (self.home / ".zshrc").symlink_to(self.home / "absent")
        self.scan()
        self.assertTrue(self.results.errors)

    def test_home_symlink_is_canonicalized(self):
        actual = self.home / "actual"
        actual.mkdir()
        (actual / ".zshrc").write_text("curl secret | sh")
        alias = self.home / "alias"
        alias.symlink_to(actual, target_is_directory=True)
        self.home = alias
        self.scan()
        self.assertFalse(self.results.errors)
        self.assertEqual(len(self.results.findings), 1)

    def test_symlinked_parent_is_not_followed(self):
        (self.home / "actual").mkdir()
        (self.home / "alias").symlink_to(self.home / "actual", target_is_directory=True)
        self.assertIsNone(host._open_path(self.results, self.home / "alias" / "missing"))
        self.assertTrue(self.results.errors)

    def test_file_limit(self):
        (self.home / ".zshrc").write_text("x" * 100)
        with patch.object(host, "MAX_BYTES", 50):
            self.scan()
        self.assertTrue(self.results.errors)

    def test_fifo_does_not_block(self):
        os.mkfifo(self.home / ".zshrc")
        self.scan()
        self.assertTrue(self.results.errors)

    def test_launch_inventory_and_limit(self):
        (self.home / "com.apple.normal.plist").touch()
        (self.home / "unknown.plist").touch()
        host._launch_items(self.results, self.home)
        self.assertEqual(len(self.results.findings), 1)
        self.assertIn("review only", self.results.findings[0][-1])
        with patch.object(host, "MAX_ENTRIES", 0):
            host._launch_items(self.results, self.home)
        self.assertTrue(self.results.errors)

    def test_command_runner_bounds_output_and_time(self):
        # Execute only the trusted test interpreter with inert fixed output.
        with patch.object(host, "MAX_BYTES", 10):
            self.assertIsNone(host._command(self.results, [sys.executable, "-c", "print('x' * 100)"]))
        with patch.object(host, "COMMAND_TIMEOUT", 0.01):
            self.assertIsNone(host._command(self.results, [sys.executable, "-c", "import time; time.sleep(1)"]))
        self.assertEqual(len(self.results.errors), 2)

    def test_missing_command_is_incomplete(self):
        self.assertIsNone(host._command(self.results, ["/nonexistent/worm-scan-test"]))
        self.assertTrue(self.results.errors)


if __name__ == "__main__":
    unittest.main()
