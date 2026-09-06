#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["PyYAML==6.0.3"]
# ///
"""
Skill Packager - Creates a distributable zip file of a skill folder

Usage:
    uv run --script scripts/package_skill.py <path/to/skill-folder> [output-directory]

Example:
    uv run --script scripts/package_skill.py skills/public/my-skill
    uv run --script scripts/package_skill.py skills/public/my-skill ./dist
"""

import sys
import zipfile
import tempfile
from pathlib import Path
from quick_validate import validate_skill


def package_skill(skill_path, output_dir=None):
    """
    Package a skill folder into a zip file.

    Args:
        skill_path: Path to the skill folder
        output_dir: Optional output directory for the zip file (defaults to current directory)

    Returns:
        Path to the created zip file, or None if error
    """
    skill_path = Path(skill_path).resolve()

    # Validate skill folder exists
    if not skill_path.exists():
        print(f"ERROR: Error: Skill folder not found: {skill_path}")
        return None

    if not skill_path.is_dir():
        print(f"ERROR: Error: Path is not a directory: {skill_path}")
        return None

    # Validate SKILL.md exists
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        print(f"ERROR: Error: SKILL.md not found in {skill_path}")
        return None

    # Run validation before packaging
    print("Checking Validating skill...")
    valid, message = validate_skill(skill_path)
    if not valid:
        print(f"ERROR: Validation failed: {message}")
        print("   Please fix the validation errors before packaging.")
        return None
    print(f"OK: {message}\n")

    # Determine output location
    skill_name = skill_path.name
    output_path = Path(output_dir).resolve() if output_dir else Path.cwd()
    zip_filename = output_path / f"{skill_name}.zip"

    # Inspect members before opening output. Never follow bundled symlinks or
    # include the archive itself when the output directory is inside the skill.
    temporary_zip = None
    try:
        members = []
        for file_path in sorted(skill_path.rglob('*')):
            if file_path.is_symlink():
                raise ValueError(f"Symbolic links cannot be packaged: {file_path}")
            relative = file_path.relative_to(skill_path)
            if file_path == zip_filename or any(part in {'.git', '__pycache__'} for part in relative.parts):
                continue
            if file_path.is_file():
                members.append(file_path)
            elif not file_path.is_dir():
                raise ValueError(f"Unsupported resource type: {file_path}")
        output_path.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=output_path, suffix='.zip', delete=False) as temporary:
            temporary_zip = Path(temporary.name)
        with zipfile.ZipFile(temporary_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for file_path in members:
                arcname = file_path.relative_to(skill_path.parent)
                zipf.write(file_path, arcname)
                print(f"  Added: {arcname}")
        temporary_zip.replace(zip_filename)

        print(f"\nOK: Successfully packaged skill to: {zip_filename}")
        return zip_filename

    except (OSError, ValueError, zipfile.BadZipFile) as e:
        print(f"ERROR: Error creating zip file: {e}")
        return None
    finally:
        if temporary_zip is not None:
            temporary_zip.unlink(missing_ok=True)


def main():
    if len(sys.argv) not in (2, 3):
        print("Usage: uv run --script scripts/package_skill.py <path/to/skill-folder> [output-directory]")
        print("\nExample:")
        print("  uv run --script scripts/package_skill.py skills/public/my-skill")
        print("  uv run --script scripts/package_skill.py skills/public/my-skill ./dist")
        sys.exit(1)

    skill_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None

    print(f"Packaging Packaging skill: {skill_path}")
    if output_dir:
        print(f"   Output directory: {output_dir}")
    print()

    result = package_skill(skill_path, output_dir)

    if result:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
