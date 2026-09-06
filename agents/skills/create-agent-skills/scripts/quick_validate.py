#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["PyYAML==6.0.3"]
# ///
"""Validate a shared skill's frontmatter and local structure."""

import re
import sys
from pathlib import Path


NAME_PATTERN = re.compile(r"^[a-z0-9-]+$")
LOCAL_LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def valid_skill_name(name):
    return (isinstance(name, str) and 1 <= len(name) <= 64
            and NAME_PATTERN.fullmatch(name) is not None
            and not name.startswith("-") and not name.endswith("-")
            and "--" not in name)


def _load_yaml(frontmatter):
    try:
        import yaml
    except ModuleNotFoundError:
        return None, (
            "PyYAML is required for validation. Run with "
            "`uv run --with pyyaml python scripts/quick_validate.py <skill-directory>`."
        )

    try:
        value = yaml.safe_load(frontmatter)
    except yaml.YAMLError as error:
        return None, f"Invalid YAML frontmatter: {error}"

    if not isinstance(value, dict):
        return None, "YAML frontmatter must be a mapping"
    return value, None


def _local_markdown_targets(content):
    fence_marker = None
    fence_length = 0

    for line in content.splitlines():
        stripped = line.lstrip()
        fence = re.match(r"^(`{3,}|~{3,})(.*)$", stripped)
        if fence:
            marker, suffix = fence.groups()
            if fence_marker is None:
                fence_marker = marker[0]
                fence_length = len(marker)
            elif marker[0] == fence_marker and len(marker) >= fence_length and not suffix.strip():
                fence_marker = None
            continue
        if fence_marker is not None:
            continue

        for raw_target in LOCAL_LINK_PATTERN.findall(line):
            target = raw_target.strip()
            if target.startswith("<") and ">" in target:
                target = target[1:target.index(">")]
            else:
                target = target.split(' "', 1)[0]
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target = target.split("#", 1)[0]
            if target:
                yield target

def validate_skill(skill_path):
    """Return ``(valid, message)`` without changing the skill directory."""
    skill_path = Path(skill_path)
    
    # Check SKILL.md exists
    skill_md = skill_path / 'SKILL.md'
    if not skill_md.exists():
        return False, "SKILL.md not found"
    
    # Read and validate frontmatter
    try:
        content = skill_md.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return False, f"Cannot read SKILL.md: {error}"
    if not content.startswith('---'):
        return False, "No YAML frontmatter found"
    
    # Extract frontmatter
    match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not match:
        return False, "Invalid frontmatter format"
    
    frontmatter = match.group(1)
    
    metadata, error = _load_yaml(frontmatter)
    if error:
        return False, error

    errors = []
    name = metadata.get("name")
    description = metadata.get("description")

    if not isinstance(name, str) or not name.strip():
        errors.append("frontmatter `name` must be a non-empty string")
    else:
        name = name.strip()
        if len(name) > 64:
            errors.append("frontmatter `name` exceeds 64 characters")
        if not NAME_PATTERN.fullmatch(name):
            errors.append("frontmatter `name` must use lowercase letters, digits, and hyphens")
        if name.startswith("-") or name.endswith("-") or "--" in name:
            errors.append("frontmatter `name` cannot start/end with a hyphen or contain `--`")
        if skill_path.name != name:
            errors.append(f"skill folder `{skill_path.name}` does not match frontmatter name `{name}`")

    if not isinstance(description, str) or not description.strip():
        errors.append("frontmatter `description` must be a non-empty string")
    else:
        description = description.strip()
        if len(description) > 1024:
            errors.append("frontmatter `description` exceeds 1024 characters")
        if "<" in description or ">" in description:
            errors.append("frontmatter `description` cannot contain angle brackets")

    line_count = len(content.splitlines())
    if line_count > 500:
        errors.append(f"SKILL.md has {line_count} lines; move conditional detail into references")

    for target in _local_markdown_targets(content):
        resolved = (skill_md.parent / target).resolve()
        if not resolved.exists():
            errors.append(f"linked local resource does not exist: {target}")

    if errors:
        return False, "Skill validation failed:\n- " + "\n- ".join(errors)
    return True, "Skill is valid"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: uv run --script quick_validate.py <skill_directory>")
        sys.exit(1)
    
    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
