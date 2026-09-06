#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["PyYAML==6.0.3"]
# ///
"""Exercise authoring tools against disposable directories only."""

import contextlib
import io
import os
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from init_skill import init_skill
from package_skill import package_skill
from quick_validate import validate_skill


class SkillToolsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))

    def scaffold(self, name="test-skill"):
        skill = init_skill(name, self.root / "skills")
        self.assertIsNotNone(skill)
        return skill

    def test_scaffold_validates_and_does_not_overwrite(self):
        skill = self.scaffold()
        self.assertEqual(validate_skill(skill), (True, "Skill is valid"))
        (skill / "SKILL.md").write_text("user content")
        self.assertIsNone(init_skill("test-skill", self.root / "skills"))
        self.assertEqual((skill / "SKILL.md").read_text(), "user content")

    def test_invalid_names_cannot_create_paths(self):
        names = ("../escaped", "a/b", str(self.root / "absolute"), "", "A", "a b", "-a", "a-", "a--b", "a" * 65)
        for name in names:
            with self.subTest(name=name):
                self.assertIsNone(init_skill(name, self.root / "skills"))
        self.assertEqual(list(self.root.iterdir()), [])

    def test_maximum_length_name(self):
        self.assertTrue(validate_skill(self.scaffold("a" * 64))[0])

    def test_round_trip_and_in_tree_output(self):
        skill = self.scaffold()
        (skill / "__pycache__").mkdir()
        (skill / "__pycache__" / "helper.pyc").write_bytes(b"cache")
        for _ in range(2):
            archive = package_skill(skill, skill)
            self.assertIsNotNone(archive)
            with zipfile.ZipFile(archive) as zipped:
                names = zipped.namelist()
                self.assertNotIn("test-skill/test-skill.zip", names)
                self.assertFalse(any("__pycache__" in name for name in names))
                extracted = self.root / "unpacked"
                zipped.extractall(extracted)
                self.assertTrue(validate_skill(extracted / skill.name)[0])

    def test_symlinks_fail_before_output_is_changed(self):
        skill = self.scaffold()
        outside = self.root / "private.txt"
        outside.write_text("private fixture")
        archive = package_skill(skill, self.root / "out")
        previous = archive.read_bytes()
        for target in (outside, skill / "SKILL.md", self.root / "missing", skill / "references"):
            link = skill / "link"
            link.symlink_to(target)
            self.assertIsNone(package_skill(skill, archive.parent))
            self.assertEqual(archive.read_bytes(), previous)
            link.unlink()

    def test_write_failure_preserves_previous_archive_and_removes_partial(self):
        skill = self.scaffold()
        archive = package_skill(skill, self.root / "out")
        previous = archive.read_bytes()
        with patch.object(zipfile.ZipFile, "write", side_effect=OSError("fixture write failure")):
            self.assertIsNone(package_skill(skill, archive.parent))
        self.assertEqual(archive.read_bytes(), previous)
        self.assertEqual(list(archive.parent.iterdir()), [archive])

    def test_invalid_skill_and_invalid_destination(self):
        self.assertIsNone(package_skill(self.root / "missing"))
        skill = self.scaffold()
        destination = self.root / "file"
        destination.write_text("keep")
        self.assertIsNone(package_skill(skill, destination))
        self.assertEqual(destination.read_text(), "keep")
        (skill / "SKILL.md").write_text("invalid")
        self.assertIsNone(package_skill(skill, self.root / "out"))
        self.assertFalse((self.root / "out").exists())

    def test_unreadable_or_special_resources_fail(self):
        skill = self.scaffold()
        (skill / "SKILL.md").write_bytes(b"\xff")
        self.assertFalse(validate_skill(skill)[0])
        self.assertIsNone(package_skill(skill, self.root / "out"))
        (skill / "SKILL.md").write_text("---\nname: test-skill\ndescription: Test resource types\n---\n")
        os.mkfifo(skill / "pipe")
        self.assertIsNone(package_skill(skill, self.root / "out"))
        self.assertFalse((self.root / "out").exists())


if __name__ == "__main__":
    unittest.main()
