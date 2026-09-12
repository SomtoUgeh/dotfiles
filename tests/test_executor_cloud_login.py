#!/usr/bin/env -S uv run --script
import io
import json
import sys
import os
import subprocess
import tempfile
import urllib.error
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch
from urllib.parse import urlencode
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
from executor_cloud_login import authorization_port, login, discover_endpoint
from executor_cloud_remote import probe

class LoginTests(unittest.TestCase):
    def test_stalled_adapter_has_short_timeout(self):
        config = '[mcp_servers.executor_cloud]\ncommand="node"\nargs=["/modules/mcp-remote/dist/proxy.js", "https://executor.example/mcp"]'
        process = MagicMock()
        process.poll.return_value = 0
        with patch('executor_cloud_remote.Path.read_text', return_value=config), \
             patch('executor_cloud_remote.subprocess.Popen', return_value=process), \
             patch('executor_cloud_remote.threading.Thread'), \
             patch('executor_cloud_remote.emit'), \
             patch('executor_cloud_remote.time.monotonic', side_effect=[0, 46]):
            with self.assertRaisesRegex(RuntimeError, 'initialization timed out'):
                probe()

    def test_discovery_identifies_client_and_reports_http_failure(self):
        response = MagicMock()
        response.__enter__.return_value = io.StringIO('{"authorization_endpoint":"https://access.example/authorize"}')
        with patch('executor_cloud_login.urllib.request.urlopen', return_value=response) as request:
            self.assertEqual(discover_endpoint('https://executor.example/mcp'), 'https://access.example/authorize')
        self.assertEqual(request.call_args.args[0].get_header('User-agent'), 'executor-cloud-login/1.0')
        error = urllib.error.HTTPError('https://executor.example', 403, 'private response', {}, None)
        with patch('executor_cloud_login.urllib.request.urlopen', side_effect=error):
            with self.assertRaisesRegex(RuntimeError, 'OAuth discovery returned HTTP 403'):
                discover_endpoint('https://executor.example/mcp')

    def test_ssh_remains_available_when_executor_fails(self):
        source = (Path(__file__).resolve().parent.parent / 'shell/.zshrc').read_text()
        function = source[source.index('function altschool-up() {'):source.index('\n# ============================================================================', source.index('function altschool-up() {'))]
        with tempfile.TemporaryDirectory() as directory:
            for command in ['ssh', 'pgrep']:
                path = Path(directory) / command
                path.write_text('#!/bin/sh\nexit 0\n')
                path.chmod(0o700)
            for args, login_status, expected, entered in [('--ssh', 17, 23, True), ('', 17, 17, False), ('--ssh', 130, 130, False), ('--ssh', 0, 23, True)]:
                script = function + f'\nfunction executor-cloud-login() {{ return {login_status}; }}\nfunction ssh() {{ print SHELL_ENTERED; return 23; }}\naltschool-up {args}\n'
                result = subprocess.run(['/bin/zsh', '-c', script], env={**os.environ, 'PATH':directory+':/usr/bin:/bin'}, text=True, capture_output=True)
                with self.subTest(args=args, status=login_status):
                    self.assertEqual(result.returncode, expected)
                    self.assertEqual('SHELL_ENTERED' in result.stdout, entered)

    def test_cached_login_never_opens_browser(self):
        process = MagicMock()
        process.stdout = io.StringIO(json.dumps({'kind': 'ready'})+'\n')
        with patch('executor_cloud_login.subprocess.Popen', return_value=process) as launch, \
             patch('executor_cloud_login.webbrowser.open') as browser:
            login('altschool')
        self.assertEqual(launch.call_count, 1)
        browser.assert_not_called()
        process.stdin.close.assert_called_once()

    def test_failed_probe_closes_connection(self):
        process = MagicMock()
        process.stdout = io.StringIO(json.dumps({'kind': 'failed', 'message': 'read failed'})+'\n')
        with patch('executor_cloud_login.subprocess.Popen', return_value=process), \
             patch('executor_cloud_login.webbrowser.open') as browser:
            with self.assertRaisesRegex(RuntimeError, 'read failed'):
                login('altschool')
        browser.assert_not_called()
        process.stdin.close.assert_called_once()

    def test_callback_collision_does_not_open_browser(self):
        endpoint = 'https://access.example/authorize'
        cloud = 'https://executor.example/mcp'
        url = endpoint+'?'+urlencode({'resource': cloud, 'code_challenge_method': 'S256',
                                     'redirect_uri': 'http://localhost:17907/oauth/callback'})
        process = MagicMock()
        process.stdout = io.StringIO('\n'.join(json.dumps(e) for e in [
            {'kind': 'config', 'url': cloud}, {'kind': 'authorize', 'url': url}])+'\n')
        forwarding = MagicMock()
        forwarding.poll.return_value = 255
        with patch('executor_cloud_login.subprocess.Popen', side_effect=[process, forwarding]), \
             patch('executor_cloud_login.discover_endpoint', return_value=endpoint), \
             patch('executor_cloud_login.webbrowser.open') as browser:
            with self.assertRaisesRegex(RuntimeError, 'Cannot forward callback port'):
                login('altschool')
        browser.assert_not_called()
        process.stdin.close.assert_called_once()

    def test_callback_validation(self):
        endpoint = 'https://access.example/authorize'
        cloud = 'https://executor.example/mcp'
        query = {'resource': cloud, 'code_challenge_method': 'S256',
                 'redirect_uri': 'http://localhost:17907/oauth/callback'}
        self.assertEqual(authorization_port(endpoint+'?'+urlencode(query), cloud, endpoint), 17907)
        for redirect in ['http://evil.example:17907/oauth/callback',
                         'http://localhost:80/oauth/callback',
                         'https://localhost:17907/oauth/callback',
                         'http://localhost:17907/other',
                         'http://user@localhost:17907/oauth/callback']:
            with self.subTest(redirect=redirect), self.assertRaises(ValueError):
                authorization_port(endpoint+'?'+urlencode({**query, 'redirect_uri':redirect}), cloud, endpoint)
        for field, value in [('resource', 'https://other.example/mcp'), ('code_challenge_method', 'plain')]:
            with self.assertRaises(ValueError):
                authorization_port(endpoint+'?'+urlencode({**query, field:value}), cloud, endpoint)
        with self.assertRaises(ValueError):
            authorization_port('https://evil.example/authorize?'+urlencode(query), cloud, endpoint)

if __name__ == '__main__': unittest.main()
