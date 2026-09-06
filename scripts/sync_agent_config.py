#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.13.3"]
# ///
"""Seed Codex defaults and refresh managed hooks without overwriting local settings."""

import argparse
from collections.abc import MutableMapping
from copy import deepcopy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shlex
import tempfile

import tomlkit

REPO = Path(__file__).resolve().parent.parent
OVERLAPPING_PLUGIN_SKILLS = {
    "build-web-apps": ("react-best-practices", "stripe-best-practices"),
    "product-design": ("image-to-code",),
}


def seed_defaults(current, defaults) -> None:
    for key, value in defaults.items():
        if key not in current:
            current[key] = deepcopy(value)
        elif isinstance(current[key], MutableMapping) and isinstance(value, MutableMapping):
            seed_defaults(current[key], value)


def seed_skill_choices(current, home: Path) -> None:
    """Disable overlapping plugin copies without disabling same-named owners.

    Codex name selectors affect every matching skill. Path selectors keep the
    dedicated Stripe and shared image skills enabled. Rediscover versioned cache
    paths on each sync; preserve explicit choices already made in Manage Skills.
    """
    cache = home / ".codex/plugins/cache"
    paths = sorted(path for plugin, skills in OVERLAPPING_PLUGIN_SKILLS.items()
                   for skill in skills
                   for path in cache.glob(f"*/{plugin}/*/skills/{skill}/SKILL.md")
                   if path.is_file())
    if not paths:
        return
    overrides = current.setdefault("skills", tomlkit.table()).setdefault("config", tomlkit.aot())
    configured = {str(entry.get("path")) for entry in overrides}
    for path in paths:
        if str(path) not in configured:
            entry = tomlkit.table()
            entry["path"] = str(path)
            entry["enabled"] = False
            overrides.append(entry)


def render_hooks(home: Path, repo: Path) -> dict:
    data = json.loads((repo / "agents/codex/hooks.json").read_text())
    for groups in data["hooks"].values():
        for group in groups:
            for hook in group["hooks"]:
                # The template contains quoted path placeholders. Shell-quote
                # their resolved values so spaces and shell metacharacters work.
                command = hook["command"]
                command = command.replace('"${DOTFILES_DIR}/agents/shared/hooks/git_guard.py"', shlex.quote(str(repo / "agents/shared/hooks/git_guard.py")))
                command = command.replace('"${HOME}/.agents/skills/shaping/shaping-ripple.sh"', shlex.quote(str(home / ".agents/skills/shaping/shaping-ripple.sh")))
                hook["command"] = command
    return data


def merge_hooks(current: dict, defaults: dict) -> dict:
    merged = deepcopy(current)
    events = merged.setdefault("hooks", {})
    managed = ("git_guard.py", "shaping-ripple.sh")
    for event in list(events):
        kept = []
        for group in events[event]:
            group = deepcopy(group)
            group["hooks"] = [hook for hook in group.get("hooks", [])
                              if not any(name in hook.get("command", "") for name in managed)
                              and not (event == "Stop" and hook.get("command", "").strip('"').endswith("/.local/bin/plannotator"))]
            if group["hooks"]:
                kept.append(group)
        if kept:
            events[event] = kept
        else:
            del events[event]
    for event, groups in defaults["hooks"].items():
        events[event] = deepcopy(groups) + events.get(event, [])
    return merged


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        backup = path.with_name(path.name + ".backup." + stamp)
        with backup.open("xb") as file:
            os.chmod(backup, 0o600)
            file.write(path.read_bytes())
    fd, name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as file:
            file.write(content)
            file.flush()
            os.fsync(file.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def sync(home: Path, repo: Path, check: bool = False) -> list[Path]:
    config = home / ".codex/config.toml"
    hooks = home / ".codex/hooks.json"
    current_text = config.read_text() if config.exists() else ""
    current = tomlkit.parse(current_text)
    defaults = tomlkit.parse((repo / "agents/codex/config.toml").read_text())
    seed_defaults(current, defaults)
    seed_skill_choices(current, home)
    # Only retire the obsolete bundled notifier when its executable is missing.
    notify = current.get("notify")
    if isinstance(notify, list) and notify and "/plugins/cache/openai-bundled/computer-use/" in str(notify[0]):
        executable = str(notify[0]).replace("${HOME}", str(home))
        if not Path(executable).exists():
            del current["notify"]
    current_hooks = json.loads(hooks.read_text()) if hooks.exists() else {}
    outputs = {config: tomlkit.dumps(current), hooks: json.dumps(merge_hooks(current_hooks, render_hooks(home, repo)), indent=2) + "\n"}
    # Parse both inputs before writing either. Never modify hook trust records.
    changed = []
    for path, content in outputs.items():
        if path.is_symlink() or not path.exists() or path.read_text() != content:
            changed.append(path)
            if not check:
                atomic_write(path, content)
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--check", action="store_true", help="report changes without writing")
    args = parser.parse_args()
    changed = sync(args.home.resolve(), REPO, args.check)
    for path in changed:
        print(f"{'Would update' if args.check else 'Updated'}: {path}")
    if not changed:
        print("Codex defaults and managed hooks are current")
    if args.check and changed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
