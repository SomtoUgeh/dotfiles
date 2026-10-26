#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.13.3", "json5==0.12.1"]
# ///
"""Point the five Mac agents at Executor 2: the cloud instance and the Mac-local instance.

- executor_v2: the cloud Executor 2 (internet services).
- executor_v2_local: the Mac's Executor 2 on 127.0.0.1:4312 (desktop tools via the stdio bridge).

Every agent connects natively over streamable HTTP and signs in with OAuth on first use:
Claude Code and Grok via `/mcp`, Codex via `codex mcp login <name>`, Cursor via
`cursor-agent mcp login <name>`, OpenCode via `opencode mcp auth <name>`. (mcp-remote 0.13.5
cannot sign in: it drops the RFC 9207 `iss` parameter Executor 2 returns.)
With --retire-v1 the Executor 1 entries (`executor`, `executor_cloud`) are removed; rerun
setup_executor.py to restore them.
"""

import argparse
from collections.abc import MutableMapping
import json
from pathlib import Path
from urllib.parse import urlsplit

import json5
import tomlkit
from sync_agent_config import atomic_write

DEFAULT_CLOUD = "https://executor-v2.julds.com/mcp"
DEFAULT_LOCAL = "http://127.0.0.1:4312/mcp"
QUERY = "?elicitation_mode=browser"
V1 = ("executor", "executor_cloud")
GROK_ALLOW = ("MCPTool(executor_v2__*)", "MCPTool(executor_v2_local__*)")
AGENTS = [
    # relative path, server key, toml?, kind
    (".claude.json", "mcpServers", False, "claude"),
    (".grok/config.toml", "mcp_servers", True, "grok"),
    (".codex/config.toml", "mcp_servers", True, "codex"),
    (".cursor/mcp.json", "mcpServers", False, "cursor"),
    (".config/opencode/opencode.jsonc", "mcp", False, "opencode"),
]


def check_url(value: str, local: bool) -> str:
    url = urlsplit(value)
    allowed = ("http", "https") if local else ("https",)
    if (url.scheme not in allowed or not url.hostname or url.username or url.password
            or url.query or url.fragment or url.path != "/mcp"):
        raise ValueError(f"Expected a plain {'/'.join(allowed)} /mcp URL, got {value}")
    if local and url.hostname not in ("127.0.0.1", "localhost"):
        raise ValueError("The local Executor URL must be on 127.0.0.1 or localhost")
    return value


def entry(kind: str, url: str) -> dict:
    full = url + QUERY
    if kind == "claude":
        return {"type": "http", "url": full}
    if kind == "grok":
        return {"url": full, "enabled": True}
    if kind == "opencode":
        return {"type": "remote", "url": full}
    # Codex and Cursor: native streamable HTTP with OAuth.
    return {"url": full}


def setup(home: Path, cloud_url: str, local_url: str,
          retire_v1: bool = False, check: bool = False) -> list[Path]:
    check_url(cloud_url, local=False)
    check_url(local_url, local=True)
    outputs = {}
    for relative, key, is_toml, kind in AGENTS:
        path = home / relative
        original = path.read_text() if path.exists() else ""
        parse = tomlkit.parse if is_toml else (json5.loads if kind == "opencode" else json.loads)
        data = parse(original) if original else ({} if not is_toml else tomlkit.document())
        servers = data.setdefault(key, tomlkit.table() if is_toml else {})
        if kind == "opencode":
            servers = servers.setdefault("servers", {})
        if not isinstance(servers, MutableMapping):
            raise ValueError(f"Expected a server table in {path}")
        for name, url in (("executor_v2", cloud_url), ("executor_v2_local", local_url)):
            desired = entry(kind, url)
            prior = servers.get(name)
            if isinstance(prior, MutableMapping):
                # Keep a deliberate on/off choice.
                for state in ("enabled", "disabled"):
                    if state in prior:
                        desired[state] = prior[state]
            servers[name] = desired
        if retire_v1:
            for name in V1:
                servers.pop(name, None)
        if kind == "grok":
            permission = data.setdefault("permission", tomlkit.table())
            allow = permission.setdefault("allow", tomlkit.array())
            for rule in GROK_ALLOW:
                if rule not in allow:
                    allow.append(rule)
        rendered = tomlkit.dumps(data) if is_toml else json.dumps(data, indent=2) + "\n"
        if original and parse(original) == data:
            rendered = original
        if rendered != original:
            outputs[path] = rendered
    if not check:
        for path, rendered in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            atomic_write(path, rendered)
    return list(outputs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--cloud-url", default=DEFAULT_CLOUD)
    parser.add_argument("--local-url", default=DEFAULT_LOCAL)
    parser.add_argument("--retire-v1", action="store_true", help="remove the Executor 1 entries")
    parser.add_argument("--check", action="store_true", help="preview; exit 1 if changes are needed")
    args = parser.parse_args()
    try:
        changed = setup(args.home.expanduser().absolute(), args.cloud_url, args.local_url,
                        args.retire_v1, args.check)
    except (ValueError, OSError, TypeError) as error:
        parser.exit(2, f"Executor 2 setup failed: {error}\n")
    for path in changed:
        print(f"{'Would update' if args.check else 'Updated'}: {path}")
    if not changed:
        print("Executor 2 client configuration is current")
    if args.check and changed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
