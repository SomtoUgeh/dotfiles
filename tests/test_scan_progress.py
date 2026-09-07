"""Progress and terminal-interrupt behavior through the actual local scanner."""
from contextlib import contextmanager
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ScanInteractionTests(unittest.TestCase):
    @contextmanager
    def running_scan(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            tools = base / "tools"
            project = base / "project"
            tools.mkdir()
            project.mkdir()
            (project / "example.txt").write_text("ordinary text\n")
            ready = base / "ready"
            for name in ("scan_repo.sh", "worm_guard_local.py", "worm_guard_runtime.sh", "worm_guard_patterns.py"):
                (tools / name).write_bytes((ROOT / "scripts" / name).read_bytes())
            # Delay a trusted fixture helper, never the target's code. This makes
            # progress and interrupt tests independent of CPU speed or file size.
            with (tools / "worm_guard_patterns.py").open("a") as handle:
                handle.write("\nimport time\n_original_scan_text = scan_text\n"
                             "def scan_text(scanner, path, text):\n"
                             f"    Path({str(ready)!r}).write_text('ready')\n"
                             "    time.sleep(30)\n"
                             "    return _original_scan_text(scanner, path, text)\n")
            with (base / "stdout").open("w") as out, (base / "stderr").open("w") as err:
                process = subprocess.Popen(
                    ["/bin/bash", str(tools / "scan_repo.sh"), str(project)],
                    stdout=out, stderr=err, start_new_session=True,
                )
                try:
                    deadline = time.monotonic() + 5
                    while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                        time.sleep(.02)
                    self.assertTrue(ready.exists(), (base / "stderr").read_text())
                    yield process, base
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGINT)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)

    def test_progress_is_visible_while_a_file_is_being_scanned(self):
        with self.running_scan() as (process, base):
            self.assertIn("Starting scan:", (base / "stderr").read_text())
            deadline = time.monotonic() + 6
            while "Progress:" not in (base / "stderr").read_text() and time.monotonic() < deadline:
                time.sleep(.05)
            progress = (base / "stderr").read_text()
            self.assertIn("Progress: scanning files", progress)
            self.assertIn("example.txt", progress)
            self.assertIsNone(process.poll(), "progress must precede completion")

    def test_ctrl_c_is_incomplete_without_traceback(self):
        with self.running_scan() as (process, base):
            os.killpg(process.pid, signal.SIGINT)
            process.wait(timeout=5)
            output = (base / "stdout").read_text() + (base / "stderr").read_text()
            self.assertEqual(process.returncode, 2, output)
            self.assertIn("scan interrupted", output.lower())
            self.assertNotIn("Traceback", output)
            self.assertNotIn("No known worm indicators", output)


if __name__ == "__main__":
    unittest.main()
