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

import json5
import tomlkit

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from setup_executor_v2 import DEFAULT_CLOUD, DEFAULT_LOCAL, setup
from sync_agent_config import sync, REPO


class ExecutorV2Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)

    def run_setup(self, **kw):
        return setup(self.home, DEFAULT_CLOUD, DEFAULT_LOCAL, **kw)

    def test_writes_all_agents_idempotently(self):
        self.assertEqual(len(self.run_setup(check=True)), 5)
        self.assertFalse((self.home / ".codex").exists())
        self.assertEqual(len(self.run_setup()), 5)
        self.assertEqual(self.run_setup(), [])
        claude = json.loads((self.home / ".claude.json").read_text())["mcpServers"]
        self.assertEqual(claude["executor_v2"], {"type": "http", "url": DEFAULT_CLOUD + "?elicitation_mode=browser"})
        codex = tomlkit.parse((self.home / ".codex/config.toml").read_text())["mcp_servers"]
        self.assertEqual(codex["executor_v2_local"]["url"], DEFAULT_LOCAL + "?elicitation_mode=browser")
        grok = tomlkit.parse((self.home / ".grok/config.toml").read_text())
        self.assertIn("MCPTool(executor_v2_local__*)", grok["permission"]["allow"])
        opencode = json5.loads((self.home / ".config/opencode/opencode.jsonc").read_text())
        self.assertEqual(opencode["mcp"]["servers"]["executor_v2"]["type"], "remote")

    def test_retire_v1_and_keep_disabled_choice(self):
        cursor = self.home / ".cursor/mcp.json"
        cursor.parent.mkdir()
        cursor.write_text(json.dumps({"mcpServers": {"executor": {"command": "x"}, "executor_cloud": {"command": "y"},
                                                     "other": {"command": "z"}}}))
        grok = self.home / ".grok/config.toml"
        grok.parent.mkdir()
        grok.write_text('[mcp_servers.executor_v2]\nurl = "old"\nenabled = false\n')
        self.run_setup(retire_v1=True)
        servers = json.loads(cursor.read_text())["mcpServers"]
        self.assertEqual(sorted(servers), ["executor_v2", "executor_v2_local", "other"])
        self.assertIs(tomlkit.parse(grok.read_text())["mcp_servers"]["executor_v2"]["enabled"], False)

    def test_wrapper_commands_for_headless_hosts(self):
        wrapper = self.home / "executor-v2-mcp"
        wrapper.write_text("#!/bin/sh\n")
        self.run_setup(cloud_command=str(wrapper), retire_v1=True)
        claude = json.loads((self.home / ".claude.json").read_text())["mcpServers"]
        self.assertEqual(claude["executor_v2"], {"type": "stdio", "command": str(wrapper), "args": []})
        self.assertEqual(claude["executor_v2_local"]["type"], "http")
        opencode = json5.loads((self.home / ".config/opencode/opencode.jsonc").read_text())
        self.assertEqual(opencode["mcp"]["servers"]["executor_v2"], {"type": "local", "command": [str(wrapper)]})
        with self.assertRaises(ValueError):
            self.run_setup(cloud_command="relative/path")

    def test_rejects_unsafe_urls(self):
        for cloud, local in [("http://x/mcp", DEFAULT_LOCAL), (DEFAULT_CLOUD, "http://10.0.0.2/mcp"),
                             (DEFAULT_CLOUD + "?a=1", DEFAULT_LOCAL)]:
            with self.assertRaises(ValueError):
                setup(self.home, cloud, local)

    def test_sync_treats_local_v2_as_gateway(self):
        self.run_setup(retire_v1=True)
        sync(self.home, REPO)
        servers = tomlkit.parse((self.home / ".codex/config.toml").read_text())["mcp_servers"]
        defaults = tomlkit.parse((REPO / "agents/codex/config.toml").read_text())["mcp_servers"]
        from sync_agent_config import EXECUTOR_DIRECT_DEFAULTS
        for name in EXECUTOR_DIRECT_DEFAULTS:
            if name in defaults:
                self.assertNotIn(name, servers)


if __name__ == "__main__":
    unittest.main()
