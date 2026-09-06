#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["bashlex==0.18", "tomlkit==0.13.3", "PyYAML==6.0.3"]
# ///
"""Regression tests for shared agent hooks and local configuration updates."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import tomlkit

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parent.parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, REPO / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


guard = load("guard", "agents/shared/hooks/git_guard.py")
ripple = load("ripple", "agents/skills/shaping/shaping-ripple.py")
setup = load("setup", "scripts/sync_agent_config.py")
validator = load("validator", "agents/skills/create-agent-skills/scripts/quick_validate.py")


class GuardTests(unittest.TestCase):
    def test_destructive_commands_in_compounds_and_wrappers(self):
        commands = [
            "git restore --staged a && git reset --hard",
            "git checkout -b safe; git clean -fd",
            "rm -rf node_modules; git reset --hard",
            "rm -rf node_modules important", "rm -rf node_modules/../src",
            "rm -rf /tmp/../home/user", "rm --recursive --force src",
            "git -C '/repo with spaces' reset --hard",
            "git --git-dir=/repo/.git reset --merge",
            "env FOO=bar command git -c color.ui=auto reset --hard",
            "bash -lc 'git reset --hard'", "eval 'git reset --hard'",
            'printf "%s" "$(git reset --hard)"',
            "git restore -SW a", "git branch -df old", "git branch -D old",
            "git push origin +HEAD:main", "git push --force origin main",
            "git stash clear", "git rm tracked", "git checkout HEAD -- tracked",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertTrue(guard.check_destructive(command)[0])

    def test_safe_commands_and_literal_text(self):
        commands = [
            "git status", "git restore --staged a", "git restore -S a",
            "git checkout -b feature", "git branch -d merged",
            "git push --force-with-lease", "git clean -fdn", "git rm --cached a",
            "rm -rf node_modules .next dist/ /tmp/safe-test",
            'printf "%s" "git reset --hard"', "echo 'rm -rf important'",
            "cat <<'EOF'\ngit reset --hard\nEOF\n", "command -v git",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertFalse(guard.check_destructive(command)[0])

    def test_runtime_payloads(self):
        for name, key in [("Bash", "command"), ("bash", "command"), ("shell", "cmd"), ("exec_command", "cmd")]:
            self.assertEqual(guard.extract_command({"tool_name": name, "tool_input": {key: "git status"}}), "git status")
        self.assertEqual(guard.extract_command({"tool_name": "Read", "tool_input": {"command": "git reset --hard"}}), "")

    def test_invalid_payload_is_visible(self):
        result = subprocess.run([sys.executable, guard.__file__], input="[]", text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid hook payload", result.stderr)


class RippleTests(unittest.TestCase):
    def test_edit_and_multi_file_patch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "shape with spaces.md").write_text("---\nshaping: true\n---\n")
            patch = "*** Begin Patch\n*** Update File: ordinary.md\n*** Move to: shape with spaces.md\n*** Delete File: gone.md\n*** End Patch"
            payload = {"tool_name": "apply_patch", "cwd": directory, "tool_input": {"command": patch}}
            self.assertEqual(ripple.changed_paths(payload), [root / "ordinary.md", root / "shape with spaces.md"])
            for tool_input in [{"command": patch}, {"patchText": patch.replace("\n", "\r\n")}, {"file_path": "shape with spaces.md"}, {"filePath": "shape with spaces.md"}]:
                result = subprocess.run([sys.executable, ripple.__file__], input=json.dumps({"cwd": directory, "tool_input": tool_input}), text=True, capture_output=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Ripple check", result.stderr)

    def test_non_shaping_and_missing_files_are_quiet(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "ordinary.md").write_text("ordinary\n")
            for path in ["ordinary.md", "missing.md", "source.py"]:
                result = subprocess.run([sys.executable, ripple.__file__], input=json.dumps({"cwd": directory, "tool_input": {"file_path": path}}), text=True, capture_output=True)
                self.assertEqual((result.returncode, result.stderr), (0, ""))


class SkillTests(unittest.TestCase):
    def test_codex_agent_toml(self):
        agents = sorted((REPO / "agents/codex/agents").glob("*.toml"))
        self.assertTrue(agents)
        for agent in agents:
            with self.subTest(agent=agent.name):
                parsed = tomlkit.parse(agent.read_text())
                self.assertTrue(parsed.get("developer_instructions"))

    def test_documented_todo_dependency_check(self):
        content = (REPO / "agents/skills/file-todos/references/schema-and-lifecycle.md").read_text()
        section = content.split("**To verify blockers are complete before starting:**", 1)[1]
        command = section.split("```bash\n", 1)[1].split("```", 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            todos = Path(directory) / "todos"
            todos.mkdir()
            (todos / "001-complete-p1-first.md").touch()
            (todos / "002-ready-p2-second.md").touch()
            result = subprocess.run(["bash", "-c", command], cwd=directory, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ["Issue 002 not complete", "Issue 003 not complete"])

    def test_library_frontmatter_and_local_links(self):
        skills = sorted((REPO / "agents/skills").glob("*/SKILL.md"))
        self.assertTrue(skills)
        for skill in skills:
            with self.subTest(skill=skill.parent.name):
                valid, message = validator.validate_skill(skill.parent)
                self.assertTrue(valid, message)

    def test_yaml_and_link_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            skill = Path(directory) / "example"
            skill.mkdir()
            entry = skill / "SKILL.md"
            entry.write_text("---\nname: example\ndescription: >\n  Valid folded YAML.\n---\n````markdown\n```python\n[Fake](missing.md)\n```\n````\n")
            self.assertTrue(validator.validate_skill(skill)[0])
            entry.write_text("---\nname: example\ndescription: [invalid\n---\n")
            self.assertFalse(validator.validate_skill(skill)[0])
            entry.write_text("---\nname: example\ndescription: Good description\n---\n[Real](missing.md)\n")
            self.assertIn("linked local resource", validator.validate_skill(skill)[1])


class ConfigTests(unittest.TestCase):
    def test_duplicate_plugin_skills_are_disabled_by_path_after_upgrade(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cache = home / ".codex/plugins/cache/openai-curated-remote"
            def skill(plugin, version, name):
                path = cache / plugin / version / "skills" / name / "SKILL.md"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"---\nname: {name}\ndescription: Fixture\n---\n")
                return path
            duplicates = [skill("build-web-apps", "1", "react-best-practices"),
                          skill("build-web-apps", "1", "stripe-best-practices"),
                          skill("product-design", "1", "image-to-code")]
            retained = [skill("stripe", "1", "stripe-best-practices"),
                        skill("build-web-apps", "1", "frontend-app-builder"),
                        skill("product-design", "1", "ideate")]
            config = tomlkit.parse('[plugins."build-web-apps@test"]\nenabled = true\n')
            setup.seed_skill_choices(config, home)
            setup.seed_skill_choices(config, home)
            entries = config["skills"]["config"]
            self.assertEqual({entry["path"] for entry in entries}, {str(path) for path in duplicates})
            self.assertTrue(all(entry["enabled"] is False for entry in entries))
            self.assertTrue(config["plugins"]["build-web-apps@test"]["enabled"])
            self.assertTrue(all(str(path) not in {entry["path"] for entry in entries} for path in retained))
            upgraded = skill("build-web-apps", "2", "stripe-best-practices")
            setup.seed_skill_choices(config, home)
            self.assertEqual(len(entries), 4)
            self.assertIn(str(upgraded), {entry["path"] for entry in entries})
            self.assertEqual(tomlkit.parse(tomlkit.dumps(config)), config)

    def test_skill_sync_preserves_explicit_choices(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = tomlkit.document()
            setup.seed_skill_choices(config, home)
            self.assertNotIn("skills", config)
            path = home / ".codex/plugins/cache/market/product-design/1/skills/image-to-code/SKILL.md"
            path.parent.mkdir(parents=True)
            path.touch()
            config["skills"] = {"config": [{"path": str(path), "enabled": True},
                                           {"name": "unrelated", "enabled": False}]}
            setup.seed_skill_choices(config, home)
            self.assertEqual(len(config["skills"]["config"]), 2)
            self.assertTrue(config["skills"]["config"][0]["enabled"])

    def test_preserves_local_settings_custom_hooks_and_is_idempotent(self):
        with tempfile.TemporaryDirectory(prefix="agent test '") as directory:
            home = Path(directory)
            config = home / ".codex/config.toml"
            config.parent.mkdir()
            config.write_text('# local choice\nmodel = "chosen-model"\nnotify = ["/valid/local/notifier"]\n[features]\nmulti_agent = false\n[hooks]\ntrusted = ["local-hash"]\n')
            custom = {"matcher": "Bash", "hooks": [{"type": "command", "command": "custom-command"}]}
            old = {"hooks": {"PreToolUse": [custom], "Stop": [{"hooks": [{"command": '"${HOME}/.local/bin/plannotator"'}]}]}}
            (config.parent / "hooks.json").write_text(json.dumps(old))
            self.assertEqual(len(setup.sync(home, REPO)), 2)
            parsed = tomlkit.parse(config.read_text())
            self.assertEqual(parsed["model"], "chosen-model")
            self.assertFalse(parsed["features"]["multi_agent"])
            self.assertEqual(parsed["hooks"]["trusted"], ["local-hash"])
            self.assertEqual(parsed["notify"], ["/valid/local/notifier"])
            self.assertIn("# local choice", config.read_text())
            hooks = json.loads((config.parent / "hooks.json").read_text())
            self.assertIn(custom, hooks["hooks"]["PreToolUse"])
            self.assertNotIn("Stop", hooks["hooks"])
            self.assertEqual(setup.sync(home, REPO), [])
            self.assertEqual(config.stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(list(config.parent.glob("*.backup.*"))), 2)

    def test_check_mode_and_invalid_input_do_not_write(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            self.assertEqual(len(setup.sync(home, REPO, check=True)), 2)
            self.assertFalse((home / ".codex").exists())
            (home / ".codex").mkdir()
            (home / ".codex/hooks.json").write_text("invalid")
            with self.assertRaises(json.JSONDecodeError):
                setup.sync(home, REPO)
            self.assertFalse((home / ".codex/config.toml").exists())

    def test_symlink_migration_does_not_modify_source(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            source = home / "source.toml"
            source.write_text('model = "mine"\n')
            (home / ".codex").mkdir()
            target = home / ".codex/config.toml"
            target.symlink_to(source)
            setup.sync(home, REPO)
            self.assertFalse(target.is_symlink())
            self.assertEqual(source.read_text(), 'model = "mine"\n')

    def test_missing_obsolete_notify_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / ".codex").mkdir()
            target = home / ".codex/config.toml"
            target.write_text('notify = ["${HOME}/.codex/plugins/cache/openai-bundled/computer-use/old/client"]\n')
            setup.sync(home, REPO)
            self.assertNotIn("notify", tomlkit.parse(target.read_text()))


if __name__ == "__main__":
    unittest.main()
