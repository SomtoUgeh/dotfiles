"""Offline auth-probe regression tests; curl is replaced and PATH is isolated."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "auth-probe.sh"
ACCOUNT = "a" * 32
SITEKEY = "probe-public-sitekey"
TOKEN = "offline-test-token"
OAUTH_TOKEN = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJmaXh0dXJlIn0.signature_-01"
WIDGET_SECRET = "offline-widget-secret"
WIDGET = {"success": True, "result": {"sitekey": SITEKEY, "secret": WIDGET_SECRET}}
VALIDATION = {"success": False, "errors": [{"code": 10402}]}
MOCK_CURL = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

args = sys.argv[1:]
fixtures = json.loads(Path(os.environ["MOCK_RESPONSES"]).read_text())
token = fixtures["token"]
assert "CLOUDFLARE_API_TOKEN" not in os.environ, "token leaked into curl environment"
assert all(token not in arg for arg in args), "token leaked into arguments"
assert args[args.index("--config") + 1] == "-"
assert sys.stdin.read() == f'header = "Authorization: Bearer {token}"\n'
method = args[args.index("-X") + 1]
url = next(arg for arg in args if arg.startswith("https://"))
with Path(os.environ["MOCK_CALLS"]).open("a") as calls:
    calls.write(json.dumps({"method": method, "url": url}) + "\n")
response = fixtures[method]
if response.get("exit_code"):
    sys.exit(response["exit_code"])
body = response["body"]
sys.stdout.write((body if isinstance(body, str) else json.dumps(body)) + "\n" + response["http_code"])
'''


def response(body, code="200", exit_code=0):
    return {"body": body, "http_code": code, "exit_code": exit_code}


class AuthProbeTests(unittest.TestCase):
    def run_probe(self, post, delete=None, *, token=TOKEN):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "python3").symlink_to(sys.executable)
            curl = root / "curl"
            curl.write_text(MOCK_CURL)
            curl.chmod(0o700)
            fixtures = root / "responses.json"
            fixtures.write_text(json.dumps({"POST": post, "DELETE": delete, "token": token}))
            calls_path = root / "calls.jsonl"
            # No inherited credentials or real curl on PATH; unexpected commands fail.
            env = {
                "PATH": str(root),
                "CLOUDFLARE_API_TOKEN": token,
                "CLOUDFLARE_ACCOUNT_ID": ACCOUNT,
                "MOCK_RESPONSES": str(fixtures),
                "MOCK_CALLS": str(calls_path),
            }
            result = subprocess.run(
                ["/bin/bash", str(SCRIPT)], env=env, text=True,
                capture_output=True, check=True, timeout=10,
            )
            self.assertNotIn(TOKEN, result.stdout + result.stderr)
            if token:
                self.assertNotIn(token, result.stdout + result.stderr)
            self.assertNotIn(WIDGET_SECRET, result.stdout + result.stderr)
            calls = [json.loads(line) for line in calls_path.read_text().splitlines()] if calls_path.exists() else []
            return json.loads(result.stdout), calls

    def assert_calls(self, calls, methods):
        self.assertEqual([call["method"] for call in calls], methods)
        base = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}/challenges/widgets"
        self.assertEqual(calls[0]["url"], base)
        if "DELETE" in methods:
            self.assertEqual(calls[1]["url"], f"{base}/{SITEKEY}")

    def test_valid_edit_scope_without_creation(self):
        for code in ("200", "400", "422"):
            with self.subTest(code=code):
                result, calls = self.run_probe(response(VALIDATION, code))
                self.assertEqual(result["status"], "ok")
                self.assertEqual(result["account_id"], ACCOUNT)
                self.assert_calls(calls, ["POST"])

    def test_accidental_widget_deleted(self):
        result, calls = self.run_probe(response(WIDGET), response(WIDGET))
        self.assertEqual(result["status"], "ok")
        self.assert_calls(calls, ["POST", "DELETE"])

    def test_unconfirmed_cleanup_never_reports_ok(self):
        cases = [
            (response({"success": False}, "500"), "http_error", 500),
            (response("", "000", 7), "network_failure", 0),
            (response("not json"), "unexpected_response", 200),
            (response(""), "unexpected_response", 200),
            (response({}), "unexpected_response", 200),
            (response({"success": False}), "unexpected_response", 200),
            (response({"success": "true"}), "unexpected_response", 200),
            (response({"success": True}, "unknown"), "unexpected_response", 0),
        ]
        for cleanup, reason, code in cases:
            with self.subTest(cleanup=cleanup):
                result, calls = self.run_probe(response(WIDGET), cleanup)
                self.assertEqual(result, {
                    "status": "cleanup_failed", "account_id": ACCOUNT,
                    "sitekey": SITEKEY, "reason": reason, "http_code": code,
                })
                self.assert_calls(calls, ["POST", "DELETE"])

    def test_probe_network_failure(self):
        result, calls = self.run_probe(response("", "000", 7))
        self.assertEqual(result["status"], "network_failure")
        self.assert_calls(calls, ["POST"])

    def test_probe_auth_failure(self):
        for code in ("200", "401", "403"):
            with self.subTest(code=code):
                result, calls = self.run_probe(response({"success": False, "errors": [{"code": 10000}]}, code))
                self.assertEqual(result["status"], "missing_scope")
                self.assert_calls(calls, ["POST"])

    def test_malformed_probe_response(self):
        bodies = [
            "not json", "", {}, [], {"success": "true"},
            {"success": True}, {"success": True, "result": {}},
            {"success": True, "result": {"sitekey": " "}},
            {"success": False}, {"success": False, "errors": []},
            {"success": False, "errors": [{}]},
            {"success": False, "errors": [{"code": "10402"}]},
        ]
        for code in ("200", "400", "422"):
            for body in bodies:
                with self.subTest(code=code, body=body):
                    result, calls = self.run_probe(response(body, code))
                    self.assertEqual(result["status"], "upstream_failure")
                    self.assert_calls(calls, ["POST"])

    def test_missing_token_does_not_call_api(self):
        result, calls = self.run_probe(response(VALIDATION), token="")
        self.assertEqual(result["status"], "missing_token")
        self.assertEqual(calls, [])

    def test_oauth_jwt_reaches_probe_and_cleanup_without_exposure(self):
        result, calls = self.run_probe(response(WIDGET), response(WIDGET), token=OAUTH_TOKEN)
        self.assertEqual(result["status"], "ok")
        self.assert_calls(calls, ["POST", "DELETE"])

    def test_unsafe_token_never_reaches_curl(self):
        for token in ('bad"token', 'bad\\token', 'bad\ntoken', 'bad\rtoken', 'bad\ttoken',
                      'bad token', 'token"\nurl = "https://attacker.invalid',
                      'token\\noutput = "/tmp/injected"'):
            with self.subTest(token=token):
                result, calls = self.run_probe(response(VALIDATION), token=token)
                self.assertEqual(result, {"status": "missing_token", "reason": "invalid_token_format"})
                self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
