#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.13.3", "json5==0.12.1"]
# ///
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import tomlkit
import json5

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from setup_executor import ARGS, REPO, setup
from sync_agent_config import sync


class ExecutorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.exe = self.home / "executor"
        self.exe.write_text("#!/bin/sh\nexit 0\n")
        self.exe.chmod(0o700)

    def run_setup(self, **kwargs):
        return setup(self.home, str(self.exe), **kwargs)

    def test_preview_apply_idempotence_and_permissions(self):
        self.assertEqual(len(self.run_setup(check=True)), 5)
        self.assertFalse((self.home / '.codex').exists())
        paths = self.run_setup()
        self.assertEqual(len(paths), 5)
        self.assertEqual(self.run_setup(), [])
        for path in paths:
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_malformed_last_file_prevents_all_writes(self):
        p = self.home / '.cursor/mcp.json'
        p.parent.mkdir(); p.write_text('{broken')
        with self.assertRaises(ValueError): self.run_setup()
        self.assertFalse((self.home / '.codex').exists())

    def test_conflict_preserves_files(self):
        p = self.home / '.claude.json'
        original = json.dumps({'mcpServers': {'executor': {'url': 'https://custom.test/mcp'}}})
        p.write_text(original)
        with self.assertRaises(ValueError): self.run_setup()
        self.assertEqual(p.read_text(), original)
        self.assertFalse((self.home / '.codex').exists())

    def test_retirement_is_explicit_and_preserves_custom_entries(self):
        p = self.home / '.codex/config.toml'; p.parent.mkdir()
        p.write_text('# retain this\nmodel="custom"\n[mcp_servers.exa]\nurl="https://mcp.exa.ai/mcp"\n[mcp_servers.granola]\nurl="https://custom.test/mcp"\n[mcp_servers.posthog]\nurl="https://mcp-eu.posthog.com/mcp"\n')
        self.run_setup()
        self.assertNotIn('enabled', tomlkit.parse(p.read_text())['mcp_servers']['exa'])
        self.run_setup(retire_codex_direct=True)
        d = tomlkit.parse(p.read_text())
        self.assertNotIn('exa', d['mcp_servers'])
        self.assertNotIn('enabled', d['mcp_servers']['granola'])
        self.assertNotIn('posthog', d['mcp_servers'])
        self.assertEqual(d['model'], 'custom'); self.assertIn('# retain this', p.read_text())
        sync(self.home, REPO)
        self.assertNotIn('exa', tomlkit.parse(p.read_text())['mcp_servers'])
        for backup in p.parent.glob('*.backup.*'):
            self.assertEqual(backup.stat().st_mode & 0o777, 0o600)

    def test_disabled_gateway_prevents_retirement(self):
        self.run_setup()
        p = self.home / '.codex/config.toml'
        d = tomlkit.parse(p.read_text()); d['mcp_servers']['executor']['enabled'] = False
        p.write_text(tomlkit.dumps(d))
        with self.assertRaises(ValueError): self.run_setup(retire_codex_direct=True)
        self.assertEqual(self.run_setup(), [])

    def test_sync_seeds_direct_defaults_only_without_active_gateway(self):
        sync(self.home, REPO)
        p = self.home / '.codex/config.toml'
        self.assertIn('exa', tomlkit.parse(p.read_text())['mcp_servers'])
        self.run_setup(retire_codex_direct=True)
        sync(self.home, REPO)
        d = tomlkit.parse(p.read_text())
        self.assertNotIn('exa', d['mcp_servers'])
        self.assertNotIn('posthog', d['mcp_servers'])
        self.assertNotIn('paper', d['mcp_servers'])
        d['mcp_servers']['executor']['enabled'] = False
        p.write_text(tomlkit.dumps(d))
        sync(self.home, REPO)
        self.assertIn('exa', tomlkit.parse(p.read_text())['mcp_servers'])
        self.assertIn('paper', tomlkit.parse(p.read_text())['mcp_servers'])

    def test_disabled_migrated_entries_are_removed(self):
        self.run_setup()
        p = self.home / '.codex/config.toml'
        d = tomlkit.parse(p.read_text())
        d['mcp_servers']['exa'] = {'url': 'https://mcp.exa.ai/mcp', 'enabled': False}
        d['mcp_servers']['1password'] = {'command': '1password-mcp', 'enabled': False}
        p.write_text(tomlkit.dumps(d))
        self.run_setup(retire_codex_direct=True)
        servers = tomlkit.parse(p.read_text())['mcp_servers']
        self.assertNotIn('exa', servers)
        self.assertNotIn('1password', servers)
        self.assertEqual(self.run_setup(retire_codex_direct=True), [])

    def test_symlink_is_replaced_without_changing_source(self):
        source = self.home / 'source.json'; source.write_text('{"custom":true}')
        (self.home / '.claude.json').symlink_to(source)
        self.run_setup()
        self.assertEqual(source.read_text(), '{"custom":true}')
        self.assertFalse((self.home / '.claude.json').is_symlink())

    def test_macos_shim_migrates_to_native_without_node_path(self):
        package = self.home / 'node_modules/executor'
        shim = package / 'bin/executor'; shim.parent.mkdir(parents=True)
        shim.write_text('#!/usr/bin/env node\n'); shim.chmod(0o700)
        native = package.parent / 'executor-darwin-arm64/bin/executor'
        native.parent.mkdir(parents=True); native.write_text('#!/bin/sh\n'); native.chmod(0o700)
        config = self.home / '.codex/config.toml'; config.parent.mkdir()
        config.write_text(tomlkit.dumps({'mcp_servers': {'executor': {'command': str(shim), 'args': ARGS, 'startup_timeout_sec': 90}}}))
        with patch('setup_executor.platform.system', return_value='Darwin'), patch('setup_executor.platform.machine', return_value='arm64'):
            setup(self.home, str(shim))
            data = tomlkit.parse(config.read_text())['mcp_servers']['executor']
            self.assertEqual(data['command'], str(native.resolve()))
            self.assertEqual(data['startup_timeout_sec'], 90)
            self.assertEqual(setup(self.home, str(shim)), [])

    def test_opencode_preserves_existing_servers_and_permissions(self):
        path = self.home / '.config/opencode/opencode.jsonc'
        path.parent.mkdir(parents=True)
        path.write_text('{ // existing configuration\n "mcp": {"servers": {"paper": {"type": "remote", "url": "http://localhost:29979/mcp", "disabled": true,},},}, "permissions": [{"action":"read","resource":"*.env","effect":"deny"}],}')
        options = self.cloud_options()
        self.run_setup(**options)
        data = json.loads(path.read_text())
        self.assertTrue(data['mcp']['servers']['paper']['disabled'])
        self.assertEqual(data['permissions'][0]['effect'], 'deny')
        self.assertEqual(data['mcp']['servers']['executor']['command'], [str(self.exe), *ARGS])
        data['mcp']['servers']['executor_cloud']['disabled'] = True
        path.write_text(json.dumps(data))
        self.assertEqual(self.run_setup(**options), [])
        self.assertTrue(json.loads(path.read_text())['mcp']['servers']['executor_cloud']['disabled'])

    def test_opencode_conflict_prevents_other_client_writes(self):
        path = self.home / '.config/opencode/opencode.jsonc'
        path.parent.mkdir(parents=True)
        path.write_text('{"mcp":{"servers":{"executor":{"type":"remote","url":"https://custom.test/mcp"}}}}')
        with self.assertRaises(ValueError): self.run_setup()
        self.assertFalse((self.home / '.codex').exists())

    def test_opencode_retirement_preserves_custom_and_unmigrated(self):
        path = self.home / '.config/opencode/opencode.jsonc'
        path.parent.mkdir(parents=True)
        data = json5.loads((REPO / 'agents/opencode/opencode.jsonc').read_text())
        data['mcp']['servers']['context7']['headers']['custom'] = 'preserve'
        data['mcp']['servers']['custom-tool'] = {'type': 'remote', 'url': 'https://custom.test/mcp'}
        path.write_text(json.dumps(data))
        options = self.cloud_options()
        self.run_setup(**options)
        self.assertIn('paper', json.loads(path.read_text())['mcp']['servers'])
        self.run_setup(retire_opencode_direct=True, **options)
        result = json.loads(path.read_text())
        for name in ('paper', 'posthog', 'cloudflare', 'cloudflare-docs', 'digitalocean',
                     'cloudflare-bindings', 'cloudflare-builds', 'cloudflare-observability',
                     'agentation', 'shadcn'):
            self.assertNotIn(name, result['mcp']['servers'])
        for name in ('context7', 'custom-tool'):
            self.assertEqual(result['mcp']['servers'][name], data['mcp']['servers'][name])
        self.assertEqual(result['permissions'], data['permissions'])
        self.assertEqual(self.run_setup(retire_opencode_direct=True, **options), [])

    def test_opencode_retirement_requires_active_gateways_before_writes(self):
        with self.assertRaises(ValueError):
            self.run_setup(retire_opencode_direct=True)
        self.assertFalse((self.home / '.codex').exists())
        options = self.cloud_options()
        self.run_setup(**options)
        path = self.home / '.config/opencode/opencode.jsonc'
        data = json.loads(path.read_text())
        data['mcp']['servers']['executor_cloud']['disabled'] = True
        path.write_text(json.dumps(data))
        before = path.read_text()
        with self.assertRaises(ValueError):
            self.run_setup(retire_opencode_direct=True, **options)
        self.assertEqual(path.read_text(), before)

    def test_missing_executable_does_not_write(self):
        self.exe.unlink()
        with self.assertRaises(ValueError): self.run_setup()
        self.assertFalse((self.home / '.codex').exists())

    def cloud_options(self):
        proxy = self.home / 'proxy.js'
        proxy.write_text('// fixture\n')
        return {'cloud_url': 'https://executor.example/mcp',
                'node_path': str(self.exe), 'proxy_path': str(proxy)}

    def test_cloud_adapter_preserves_local_and_is_idempotent(self):
        options = self.cloud_options()
        self.run_setup()
        config = self.home / '.grok/config.toml'
        data = tomlkit.parse(config.read_text())
        data['mcp_servers']['executor_cloud'] = {'url': options['cloud_url'], 'enabled': False}
        config.write_text(tomlkit.dumps(data))
        self.assertEqual(len(self.run_setup(check=True, **options)), 5)
        self.run_setup(**options)
        data = tomlkit.parse(config.read_text())['mcp_servers']
        self.assertEqual(data['executor']['args'], ARGS)
        self.assertFalse(data['executor_cloud']['enabled'])
        self.assertEqual(data['executor_cloud']['args'][1], options['cloud_url'])
        claude = json.loads((self.home / '.claude.json').read_text())['mcpServers']
        self.assertEqual(claude['executor_cloud']['type'], 'stdio')
        self.assertEqual(self.run_setup(**options), [])
        self.assertEqual(self.run_setup(), [])

    def test_callback_migration_and_preservation(self):
        options = self.cloud_options()
        self.run_setup(**options)
        self.run_setup(**options, cloud_callback_port=17907)
        self.assertEqual(self.run_setup(**options), [])
        data = tomlkit.parse((self.home / '.codex/config.toml').read_text())
        self.assertEqual(data['mcp_servers']['executor_cloud']['args'][2], '17907')
        self.assertEqual(self.run_setup(**options, cloud_callback_port=17907), [])

    def test_timeout_upgrade_preserves_other_fields(self):
        options = self.cloud_options()
        self.run_setup(**options)
        path = self.home / '.config/opencode/opencode.jsonc'
        for old, expected in [(30000, 330000), (400000, 400000)]:
            data = json.loads(path.read_text())
            data['mcp']['servers']['executor_cloud']['timeout'] = {'startup': old, 'request': 60000}
            path.write_text(json.dumps(data))
            self.run_setup(**options)
            timeout = json.loads(path.read_text())['mcp']['servers']['executor_cloud']['timeout']
            self.assertEqual(timeout, {'startup': expected, 'request': 60000})
        for invalid in [True, -1, '30000']:
            data['mcp']['servers']['executor_cloud']['timeout'] = {'startup': invalid}
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                self.run_setup(**options)

    def test_cloud_custom_auth_conflict_prevents_all_writes(self):
        options = self.cloud_options()
        config = self.home / '.cursor/mcp.json'; config.parent.mkdir()
        original = json.dumps({'mcpServers': {'executor_cloud': {
            'url': options['cloud_url'], 'headers': {'X-Custom': 'keep'}}}})
        config.write_text(original)
        with self.assertRaises(ValueError): self.run_setup(**options)
        self.assertEqual(config.read_text(), original)
        self.assertFalse((self.home / '.codex').exists())

    def test_cloud_only_device_needs_no_local_executor(self):
        options = self.cloud_options()
        setup(self.home, None, cloud_only=True, **options)
        servers = tomlkit.parse((self.home / '.codex/config.toml').read_text())['mcp_servers']
        self.assertNotIn('executor', servers)
        self.assertIn('executor_cloud', servers)
        self.assertEqual(setup(self.home, None, cloud_only=True, **options), [])

    def test_cloud_only_cannot_retire_direct_connections(self):
        with self.assertRaises(ValueError):
            self.run_setup(cloud_only=True, retire_codex_direct=True, **self.cloud_options())
        with self.assertRaises(ValueError):
            self.run_setup(cloud_only=True)
        self.assertFalse((self.home / '.codex').exists())

    def test_cloud_rejects_insecure_or_credential_bearing_urls(self):
        options = self.cloud_options()
        for url in ('http://executor.example/mcp', 'https://user:pass@executor.example/mcp',
                    'https://executor.example/mcp?token=secret', 'https://executor.example/'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.run_setup(**{**options, 'cloud_url': url})
        self.assertFalse((self.home / '.codex').exists())

    def test_plugin_retirement_keeps_skills_and_unrelated_policies(self):
        self.run_setup()
        p = self.home / '.codex/config.toml'
        d = tomlkit.parse(p.read_text())
        d['plugins'] = {'canva@openai-curated': {'enabled': True},
                        'unrelated@test': {'enabled': True}}
        d['skills'] = {'config': [{'path': '/skills/example/SKILL.md', 'enabled': True}]}
        p.write_text(tomlkit.dumps(d))
        before = p.read_text()
        self.run_setup(retire_codex_plugins=True, check=True)
        self.assertEqual(p.read_text(), before)
        self.run_setup(retire_codex_plugins=True)
        result = tomlkit.parse(p.read_text())
        self.assertTrue(result['plugins']['canva@openai-curated']['enabled'])
        self.assertFalse(result['plugins']['canva@openai-curated']['mcp_servers']['canva']['enabled'])
        self.assertEqual(result['plugins']['unrelated@test'], d['plugins']['unrelated@test'])
        self.assertEqual(result['skills'], d['skills'])
        self.assertEqual(self.run_setup(retire_codex_plugins=True), [])
        sync(self.home, REPO)
        result = tomlkit.parse(p.read_text())
        self.assertFalse(result['plugins']['canva@openai-curated']['mcp_servers']['canva']['enabled'])
        result['mcp_servers']['executor']['enabled'] = False
        p.write_text(tomlkit.dumps(result))
        with self.assertRaises(ValueError):
            self.run_setup(retire_codex_plugins=True)


if __name__ == '__main__': unittest.main()
