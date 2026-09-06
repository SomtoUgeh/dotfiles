#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Remind agents to propagate changes to shaping documents after writes."""

import json
from pathlib import Path
import re
import sys

REMINDER = """Ripple check:
- Updated a Breadboard diagram? Update the affordance tables first, then Mermaid.
- Changed Requirements or Shape parts? Update Fit Check, Gaps, and Open Questions.
- Changed Work Streams Detail? Update Work Streams Mermaid.
"""


def changed_paths(data: dict) -> list[Path]:
    tool_input = data.get("tool_input") or data.get("input") or {}
    if isinstance(tool_input, str):
        tool_input = {"command": tool_input}
    if not isinstance(tool_input, dict):
        return []
    paths = []
    path = tool_input.get("file_path") or tool_input.get("filePath")
    if isinstance(path, str):
        paths.append(path)
    patch = tool_input.get("patchText") or tool_input.get("command") or tool_input.get("patch") or tool_input.get("input")
    if isinstance(patch, str):
        for line in patch.splitlines():
            match = re.match(r"^\*\*\* (?:Add File|Update File|Move to): (.+)$", line)
            if match:
                paths.append(match.group(1))
    cwd = data.get("cwd")
    root = Path(cwd) if isinstance(cwd, str) else Path.cwd()
    return [root / path for path in dict.fromkeys(paths) if path.endswith(".md")]


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            return 0
    except json.JSONDecodeError:
        return 0
    for path in changed_paths(data):
        try:
            with path.open() as file:
                start = [next(file, "") for _ in range(5)]
        except (OSError, UnicodeError):
            continue
        if any(re.match(r"^shaping:\s*true\s*$", line) for line in start):
            print(REMINDER, file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
