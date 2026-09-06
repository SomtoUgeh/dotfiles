# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Exercise SSH setup with a fake vault and isolated home, without credentials."""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ssh-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.repo = self.root / "repo"
        (self.repo / "scripts").mkdir(parents=True)
        shutil.copytree(ROOT / "templates", self.repo / "templates")
        signer = self.bin / "signer"
        signer.write_text("#!/bin/sh\nexit 0\n")
        signer.chmod(0o755)
        self.script = self.repo / "scripts/setup_ssh_from_1password.sh"
        self.script.write_text((ROOT / "scripts/setup_ssh_from_1password.sh").read_text().replace(
            "/Applications/1Password.app/Contents/MacOS/op-ssh-sign", str(signer)))
        agent = self.home / "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        agent.parent.mkdir(parents=True)
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.bind(str(agent))
        self.addCleanup(self.sock.close)
        (self.bin / "op").write_text('''#!/bin/sh
case "$1" in
  --version) echo test ;;
  vault) exit 0 ;;
  read)
    case "$2" in *"$MISSING_KEY"*) [ -z "$MISSING_KEY" ] || exit 1 ;; esac
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixturePublicKey'
    ;;
esac
''')
        (self.bin / "ssh-add").write_text("#!/bin/sh\necho '256 SHA256:fixture fixture (ED25519)'\n")
        for name in ("op", "ssh-add"):
            (self.bin / name).chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{self.bin}:/usr/bin:/bin", MISSING_KEY="")

    def run_setup(self, *args):
        return subprocess.run(["/bin/bash", str(self.script), *args], env=self.env,
                              text=True, capture_output=True)

    def snapshot(self):
        return {str(p.relative_to(self.home)): (p.lstat().st_mode,
                p.read_bytes() if p.is_file() else None)
                for p in self.home.rglob("*")}

    def test_check_missing_setup_creates_nothing(self):
        before = self.snapshot()
        result = self.run_setup("--check")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.home / ".ssh").exists())

    def test_create_then_check_preserves_contents_and_permissions(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        (self.home / ".ssh").chmod(0o755)
        (self.home / ".ssh/config").chmod(0o644)
        before = self.snapshot()
        result = self.run_setup("--check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_missing_signing_key_fails_without_replacing_signers(self):
        self.assertEqual(self.run_setup().returncode, 0)
        allowed = self.home / ".ssh/allowed_signers"
        before = allowed.read_bytes()
        self.env["MISSING_KEY"] = "swissblock_sign_ed25519"
        result = self.run_setup()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(allowed.read_bytes(), before)

    def test_missing_template_fails(self):
        (self.repo / "templates/ssh-config.template").unlink()
        result = self.run_setup("--check")
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing template ssh-config.template", result.stdout)


if __name__ == "__main__":
    unittest.main()
