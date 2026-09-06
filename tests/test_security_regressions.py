"""Offline regressions for checkout startup and exposed credential handling."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SecurityRegressions(unittest.TestCase):
    @unittest.skipUnless(shutil.which("zsh"), "zsh is required")
    def test_shell_ignores_project_tools_and_preserves_installed_tools(self):
        for inherited in (False, True):
            for installed in (False, True):
                with self.subTest(inherited=inherited, installed=installed):
                    with tempfile.TemporaryDirectory() as directory:
                        base = Path(directory)
                        home = base / "home"
                        project = base / "project"
                        local_bin = project / "node_modules/.bin"
                        trusted_bin = base / "trusted/bin"
                        local_bin.mkdir(parents=True)
                        trusted_bin.mkdir(parents=True)
                        (home / ".oh-my-zsh").mkdir(parents=True)
                        (home / ".oh-my-zsh/oh-my-zsh.sh").touch()
                        for name in ("direnv", "starship"):
                            program = local_bin / name
                            program.write_text("#!/bin/sh\necho 'print CHECKOUT_EXECUTED'\n")
                            program.chmod(0o755)
                            if installed:
                                program = trusted_bin / name
                                program.write_text(f"#!/bin/sh\necho 'print TRUSTED_{name}'\n")
                                program.chmod(0o755)
                        # Redirect platform installations into the fixture, so the
                        # host's installed tools cannot mask the missing-tool case.
                        source = (ROOT / "shell/.zshrc").read_text()
                        source = source.replace("/opt/homebrew", str(base / "trusted"))
                        source = source.replace("/usr/local", str(base / "trusted"))
                        source = source.replace("/Users/odera", str(home))
                        config = base / "zshrc"
                        config.write_text(source)
                        path = "/usr/bin:/bin" + (":./node_modules/.bin" if inherited else "")
                        result = subprocess.run(
                            [shutil.which("zsh"), "-f", "-c", 'source "$1"; print STARTUP_COMPLETE', "test", str(config)],
                            cwd=project, env={"HOME": str(home), "PATH": path},
                            capture_output=True, text=True, timeout=20,
                        )
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn("STARTUP_COMPLETE", result.stdout)
                        self.assertNotIn("CHECKOUT_EXECUTED", result.stdout + result.stderr)
                        for name in ("direnv", "starship"):
                            self.assertEqual(f"TRUSTED_{name}" in result.stdout, installed)

    def test_oauth_tokens_in_current_files_and_deleted_packed_history(self):
        for prefix in ("gho_", "ghu_"):
            with self.subTest(prefix=prefix), tempfile.TemporaryDirectory() as directory:
                repo = Path(directory)
                token = prefix + "AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII"
                secret = repo / "credential.json"
                secret.write_text(token)

                def scan():
                    result = subprocess.run(
                        ["/bin/bash", str(ROOT / "scripts/scan_repo.sh"), str(repo)],
                        capture_output=True, text=True, timeout=30,
                    )
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("token-shaped secret", result.stdout)
                    self.assertNotIn(token, result.stdout + result.stderr)

                scan()
                env = {"HOME": directory, "PATH": "/usr/bin:/bin",
                       "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}

                def git(*args):
                    subprocess.run(
                        ["git", "-c", "init.templateDir=", "-c", "core.hooksPath=/dev/null",
                         "-c", "user.name=Fixture", "-c", "user.email=fixture@example.test",
                         "-c", "commit.gpgsign=false", *args],
                        cwd=repo, env=env, capture_output=True, check=True,
                    )

                git("init", "-q")
                git("add", "credential.json")
                git("commit", "-qm", "synthetic credential fixture")
                git("rm", "-q", "credential.json")
                git("commit", "-qm", "remove fixture")
                git("gc", "--quiet")
                scan()

    def test_copilot_authentication_files_are_ignored(self):
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "--stdin"], cwd=ROOT,
            input="config/github-copilot/apps.json\nconfig/github-copilot/hosts.json\n",
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(len(result.stdout.splitlines()), 2)


if __name__ == "__main__":
    unittest.main()
