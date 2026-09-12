#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.13.3", "json5==0.12.1"]
# ///
"""Opt in five local agents to an installed Executor and retire migrated defaults."""

import argparse
from collections.abc import Mapping
import json
import os
import platform
from pathlib import Path
import shutil
from urllib.parse import urlsplit

import json5
import tomlkit
from sync_agent_config import EXECUTOR_DIRECT_DEFAULTS, atomic_write

REPO = Path(__file__).resolve().parent.parent
ARGS = ["mcp", "--elicitation-mode", "browser", "--no-artifacts"]
# Only these standard definitions have been exercised through the local gateway.
RETIRABLE = EXECUTOR_DIRECT_DEFAULTS
MIGRATED_PLUGIN_SERVERS = ("canva", "github", "gmail", "google-drive", "notion", "posthog")
OPENCODE_RETIRABLE = (
    "context7", "cloudflare", "cloudflare-docs", "posthog", "paper", "digitalocean",
    "cloudflare-bindings", "cloudflare-builds", "cloudflare-observability",
    "agentation", "shadcn",
)
MIGRATED_APPS = (
    "connector_68df33b1a2d081918778431a9cfca8ba",  # Canva
    "connector_76869538009648d5b282a4bb21c3d157",  # GitHub
    "connector_2128aebfecb84f64a069897515042a44",  # Gmail
    "connector_5f3c8c41a1e54ad7a76272c89e2554fa",  # Google Drive suite
    "asdk_app_699caef2d680819188727b0ddbb349dd",  # PostHog
)


def resolve_executable(executable: str) -> Path:
    path = Path(executable).expanduser().absolute()
    # The npm shim needs Node on PATH, which GUI agents may not inherit.
    # Use the installed macOS native sibling, preserving custom executables.
    package = path.resolve().parent.parent
    arch = {"arm64": "arm64", "x86_64": "x64"}.get(platform.machine())
    if platform.system() == "Darwin" and package.name == "executor" and arch:
        native = package.parent / f"executor-darwin-{arch}" / "bin/executor"
        if native.is_file() and os.access(native, os.X_OK):
            return native
    return path


def setup(home: Path, executable: str | None, check: bool = False,
          retire_codex_direct: bool = False, retire_codex_plugins: bool = False,
          cloud_url: str | None = None, node_path: str | None = None,
          proxy_path: str | None = None, cloud_only: bool = False,
          retire_opencode_direct: bool = False, cloud_callback_port: int | None = None) -> list[Path]:
    if cloud_callback_port is not None and (not cloud_url or not 1024 <= cloud_callback_port <= 65535):
        raise ValueError("Cloud callback port requires --cloud-url and must be 1024-65535")
    if cloud_only and (not cloud_url or retire_codex_direct or retire_codex_plugins):
        raise ValueError("Cloud-only setup requires --cloud-url and cannot retire local integrations")
    command = resolve_executable(executable) if executable and not cloud_only else None
    if not cloud_only and (command is None or not command.is_file() or not os.access(command, os.X_OK)):
        raise ValueError("Executor executable is missing or not executable")
    cloud = None
    if cloud_url is not None:
        url = urlsplit(cloud_url)
        if (url.scheme != "https" or not url.hostname or url.username or url.password
                or url.query or url.fragment or url.path != "/mcp"):
            raise ValueError("Cloud URL must be an HTTPS /mcp endpoint without credentials or query parameters")
        node = Path(node_path or shutil.which("node") or "").expanduser().resolve()
        proxy = Path(proxy_path or shutil.which("mcp-remote") or "").expanduser().resolve()
        if not node.is_file() or not os.access(node, os.X_OK) or not proxy.is_file():
            raise ValueError("Install Node and mcp-remote, or supply --node-path and --proxy-path")
        cloud = {"command": str(node), "args": [str(proxy), cloud_url, "--auth-timeout", "300"]}
    outputs = {}
    for relative, key, is_toml in [
        (".codex/config.toml", "mcp_servers", True),
        (".grok/config.toml", "mcp_servers", True),
        (".claude.json", "mcpServers", False),
        (".cursor/mcp.json", "mcpServers", False),
        (".config/opencode/opencode.jsonc", "mcp", False),
    ]:
        path = home / relative
        is_opencode = relative == ".config/opencode/opencode.jsonc"
        if is_opencode and (home / ".config/opencode/opencode.json").exists():
            raise ValueError("OpenCode has opencode.json; review configuration precedence before setup")
        parse_json = json5.loads if is_opencode else json.loads
        original = path.read_text() if path.exists() else ""
        data = (tomlkit.parse(original) if is_toml else
                parse_json(original) if original else {})
        if not isinstance(data, Mapping):
            raise ValueError(f"Expected an object in {path}")
        servers = data.setdefault(key, tomlkit.table() if is_toml else {})
        if not isinstance(servers, Mapping):
            raise ValueError(f"Expected a server table in {path}")
        if is_opencode:
            servers = servers.setdefault("servers", {})
            if not isinstance(servers, Mapping):
                raise ValueError(f"Expected an OpenCode server table in {path}")
        if command is not None:
            desired = {"command": str(command), "args": ARGS}
            if relative == ".claude.json":
                desired["type"] = "stdio"
            if is_opencode:
                desired = {"type": "local", "command": [str(command), *ARGS]}
            existing = servers.get("executor")
            if existing is not None:
                if not isinstance(existing, Mapping):
                    raise ValueError(f"Invalid Executor entry in {path}")
                # Never replace an alternate gateway, transport, environment or flags.
                compatible = dict(existing)
                if isinstance(compatible.get("command"), str):
                    compatible["command"] = str(resolve_executable(compatible["command"]))
                if any(compatible.get(k) != v for k, v in desired.items()):
                    raise ValueError(f"Existing Executor configuration differs in {path}; review it manually")
                if (retire_codex_direct or retire_codex_plugins) and relative == ".codex/config.toml" and existing.get("enabled") is False:
                    raise ValueError("Cannot retire direct tools while Executor is disabled")
                existing["command"] = desired["command"]
            else:
                servers["executor"] = desired
        if cloud is not None:
            cloud_desired = dict(cloud)
            if relative == ".claude.json":
                cloud_desired["type"] = "stdio"
            if is_opencode:
                cloud_desired = {"type": "local", "command": [cloud["command"], *cloud["args"]]}
            prior = servers.get("executor_cloud")
            # A stable device-specific callback avoids collisions during SSH login.
            # Omitted CLI option preserves the existing port on subsequent setup runs.
            port = cloud_callback_port
            if isinstance(prior, Mapping):
                prior_args = prior.get("command" if is_opencode else "args", [])
                offset = 3 if is_opencode else 2
                if isinstance(prior_args, list) and len(prior_args) > offset:
                    value = prior_args[offset]
                    if isinstance(value, str) and value.isdigit() and port is None:
                        port = int(value)
            if port is not None:
                arg_key = "command" if is_opencode else "args"
                cloud_desired[arg_key] = list(cloud_desired[arg_key])
                cloud_desired[arg_key].insert(3 if is_opencode else 2, str(port))
            if prior is not None:
                if not isinstance(prior, Mapping):
                    raise ValueError(f"Invalid cloud Executor entry in {path}")
                comparable = {k: v for k, v in prior.items() if k not in ("enabled", "disabled")}
                expected = dict(cloud_desired)
                if is_opencode:
                    timeout = comparable.pop("timeout", {})
                    if not isinstance(timeout, Mapping):
                        raise ValueError(f"Invalid OpenCode timeout in {path}")
                    startup = timeout.get("startup", 330000)
                    if isinstance(startup, bool) or not isinstance(startup, (int, float)) or startup <= 0:
                        raise ValueError(f"Invalid OpenCode startup timeout in {path}")
                    cloud_desired["timeout"] = {**timeout, "startup": max(startup, 330000)}
                if cloud_callback_port is not None:
                    arg_key = "command" if is_opencode else "args"
                    offset = 3 if is_opencode else 2
                    for entry in (comparable, expected):
                        values = entry.get(arg_key)
                        if isinstance(values, list):
                            values = list(values)
                            if len(values) > offset and isinstance(values[offset], str) and values[offset].isdigit():
                                values.pop(offset)
                            entry[arg_key] = values
                # An explicit --cloud-url may replace the same plain HTTP
                # endpoint with the shared OAuth adapter; preserve custom auth.
                if comparable not in (expected, {"url": cloud_url}):
                    raise ValueError(f"Existing cloud Executor configuration differs in {path}; review it manually")
                for state in ("enabled", "disabled"):
                    if state in prior:
                        cloud_desired[state] = prior[state]
            if is_opencode:
                cloud_desired.setdefault("timeout", {"startup": 330000})
            servers["executor_cloud"] = cloud_desired
        if retire_opencode_direct and is_opencode:
            for gateway in ("executor", "executor_cloud"):
                entry = servers.get(gateway)
                if not isinstance(entry, Mapping) or entry.get("disabled") is True or entry.get("enabled") is False:
                    raise ValueError("OpenCode retirement requires both active Executor gateways")
            defaults = json5.loads((REPO / "agents/opencode/opencode.jsonc").read_text())["mcp"]["servers"]
            for name in OPENCODE_RETIRABLE:
                entry = servers.get(name)
                if not isinstance(entry, Mapping):
                    continue
                comparable = {k: v for k, v in entry.items() if k != "disabled"}
                standard = {k: v for k, v in defaults[name].items() if k != "disabled"}
                if comparable == standard:
                    del servers[name]
        if retire_codex_direct and relative == ".codex/config.toml":
            defaults = tomlkit.parse((REPO / "agents/codex/config.toml").read_text())["mcp_servers"]
            for name in RETIRABLE:
                entry = servers.get(name)
                if entry is None:
                    continue
                # Preserve custom endpoints, headers, timeouts, commands and cwd.
                comparable = {k: v for k, v in entry.items() if k != "enabled"}
                if comparable == dict(defaults[name]):
                    del servers[name]
            # 1Password is host-installed, rather than a portable template default.
            entry = servers.get("1password")
            if entry is not None and {k: v for k, v in entry.items() if k != "enabled"} == {"command": "1password-mcp"}:
                del servers["1password"]
        if retire_codex_plugins and relative == ".codex/config.toml":
            # Keep plugin enablement and skills intact. Older packages contribute
            # MCP servers; current managed packages contribute app connectors.
            for plugin_id, plugin in data.get("plugins", {}).items():
                name = plugin_id.split("@", 1)[0]
                if name in MIGRATED_PLUGIN_SERVERS:
                    overlay = plugin.setdefault("mcp_servers", tomlkit.table())
                    overlay.setdefault(name, tomlkit.table())["enabled"] = False
            apps = data.setdefault("apps", tomlkit.table())
            for app_id in MIGRATED_APPS:
                apps.setdefault(app_id, tomlkit.table())["enabled"] = False
        rendered = tomlkit.dumps(data) if is_toml else json.dumps(data, indent=2) + "\n"
        # Preserve formatting when configuration values did not change.
        parse_original = tomlkit.parse if is_toml else parse_json
        if original and parse_original(original) == data:
            rendered = original
        if rendered != original or path.is_symlink():
            outputs[path] = rendered
    # All files and conflicts are validated before the first mutation.
    if not check:
        for path, rendered in outputs.items():
            atomic_write(path, rendered)
    return list(outputs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--executor-path", default=shutil.which("executor"))
    parser.add_argument("--check", action="store_true", help="preview; exit 1 if changes are needed")
    parser.add_argument("--cloud-url", help="also connect all agents to a hosted HTTPS /mcp endpoint")
    parser.add_argument("--cloud-only", action="store_true",
                        help="configure the cloud connection without requiring or changing a local Executor")
    parser.add_argument("--cloud-callback-port", type=int,
                        help="stable OAuth callback port for this device; omission preserves its current port")
    parser.add_argument("--node-path", help="Node executable for the cloud OAuth adapter")
    parser.add_argument("--proxy-path", help="installed mcp-remote proxy.js; pin the package before setup")
    parser.add_argument("--retire-codex-direct", action="store_true",
                        help="remove standard direct Codex entries ONLY after live gateway verification")
    parser.add_argument("--retire-codex-plugins", action="store_true",
                        help="disable verified duplicate plugin MCPs/apps while retaining plugin skills")
    parser.add_argument("--retire-opencode-direct", action="store_true",
                        help="remove verified standard OpenCode duplicates; requires both active gateways")
    args = parser.parse_args()
    if not args.executor_path and not args.cloud_only:
        parser.error("Install Executor first or supply --executor-path")
    try:
        changed = setup(args.home.expanduser().absolute(), args.executor_path,
                        args.check, args.retire_codex_direct, args.retire_codex_plugins,
                        args.cloud_url, args.node_path, args.proxy_path, args.cloud_only,
                        args.retire_opencode_direct, args.cloud_callback_port)
    except (ValueError, OSError, TypeError) as error:
        parser.exit(2, f"Executor setup failed: {error}\n")
    for path in changed:
        print(f"{'Would update' if args.check else 'Updated'}: {path}")
    if not changed:
        print("Executor client configuration is current")
    if args.check and changed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
