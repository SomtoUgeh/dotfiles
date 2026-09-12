#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["tomlkit==0.13.3", "PyYAML==6.0.3"]
# ///
"""Render shared role prompts into tracked native files, preserving runtime settings."""

import argparse
from pathlib import Path
import re

import tomlkit
import yaml


REPO = Path(__file__).resolve().parent.parent


def markdown_parts(content):
    match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", content, re.DOTALL)
    if not match:
        raise ValueError("Expected YAML frontmatter and a Markdown body")
    metadata = yaml.safe_load(match[1])
    if not isinstance(metadata, dict):
        raise ValueError("Role frontmatter must be a mapping")
    return metadata, match[2].strip()


def planned_updates(repo):
    source = repo / "agents/shared/roles"
    common = (source / "_common.md").read_text().strip()
    if not common:
        raise ValueError("Shared role instructions must not be empty")
    updates = {}
    roles = sorted(path for path in source.glob("*.md") if not path.name.startswith("_"))
    if not roles:
        raise ValueError("No canonical roles found")
    for role in roles:
        metadata, body = markdown_parts(role.read_text())
        description = metadata.get("description")
        if not isinstance(description, str) or not description.strip() or not body:
            raise ValueError(f"Missing role description or body: {role}")
        instructions = f"{common}\n\n{body}\n"
        for harness in ("claude", "codex", "opencode"):
            suffix = ".toml" if harness == "codex" else ".md"
            target = repo / "agents" / harness / "agents" / (role.stem + suffix)
            original = target.read_text()
            if harness == "codex":
                native = tomlkit.parse(original)
                native["description"] = description
                native["developer_instructions"] = tomlkit.string(instructions, multiline=True)
                rendered = tomlkit.dumps(native)
            else:
                native, _ = markdown_parts(original)
                native["description"] = description
                header = yaml.safe_dump(native, sort_keys=False, allow_unicode=True, width=1000).rstrip()
                rendered = f"---\n{header}\n---\n\n{instructions}"
            if original != rendered:
                updates[target] = rendered
    return updates


def sync(repo=REPO, *, check=False):
    # Parse every input before writing, so malformed sources do not cause a
    # partially regenerated library. This command never touches host-local config.
    updates = planned_updates(repo)
    if not check:
        for path, content in updates.items():
            path.write_text(content)
    return list(updates)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report drift without writing")
    args = parser.parse_args()
    changed = sync(check=args.check)
    for path in changed:
        print(path.relative_to(REPO))
    if not changed:
        print("Role prompts are synchronized.")
    return int(args.check and bool(changed))


if __name__ == "__main__":
    raise SystemExit(main())
