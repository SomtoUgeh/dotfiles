#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["bashlex==0.18"]
# ///
"""Inspect literal destructive shell commands; this tripwire is not a sandbox.

Checks every command, including substitutions. Aliases, computed commands and
code in other interpreters still require the harness's permission boundary.
"""

import json
import posixpath
import re
import shlex
import sys

import bashlex

# bashlex 0.18 leaves quote removal unimplemented in heredoc delimiters.
# Correct that narrow parser gap using the standard shell-word lexer.
_read_heredoc = bashlex.heredoc.makeheredoc


def read_heredoc(tokenizer, redirect, line, strip_tabs):
    delimiter = shlex.split(redirect.output.word)
    if len(delimiter) == 1:
        redirect.output.word = delimiter[0]
    return _read_heredoc(tokenizer, redirect, line, strip_tabs)


bashlex.heredoc.makeheredoc = read_heredoc

BUILD_DIRS = {"node_modules", ".next", "dist", "build", "__pycache__",
              ".pytest_cache", ".mypy_cache", "target", ".gradle", ".cache"}
GIT_VALUE_FLAGS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}


def unwrap(words: list[str]) -> list[str]:
    while words and posixpath.basename(words[0]) in {"command", "builtin", "exec", "env", "sudo", "noglob"}:
        wrapper, *words = words
        if posixpath.basename(wrapper) == "command" and words and words[0] in {"-v", "-V"}:
            return []
        while words:
            word = words[0]
            if word == "--":
                words = words[1:]
                break
            if word.startswith("-"):
                takes_value = word in {"-u", "--user", "-g", "--group", "-C", "--chdir", "--unset"}
                words = words[2 if takes_value else 1:]
            elif posixpath.basename(wrapper) == "env" and re.match(r"^[A-Za-z_][A-Za-z_0-9]*=", word):
                words = words[1:]
            else:
                break
    return words


def safe_cleanup_target(target: str) -> bool:
    if any(char in target for char in "$" + chr(96) + "*?[") or ".." in target.split("/"):
        return False
    path = posixpath.normpath(target)
    return path.startswith(("/tmp/", "/var/tmp/")) or (
        not path.startswith("/") and path.split("/")[0] in BUILD_DIRS
    )


def short_flags(args: list[str]) -> set[str]:
    return set("".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--")))


def check_words(words: list[str], depth: int) -> str:
    words = unwrap(words)
    if not words:
        return ""
    executable, *args = words
    executable = posixpath.basename(executable)
    if executable in {"bash", "sh", "zsh", "dash", "ksh"}:
        for index, arg in enumerate(args):
            if arg.startswith("-") and not arg.startswith("--") and "c" in arg[1:]:
                if index + 1 < len(args):
                    return check_destructive(args[index + 1], depth + 1)[1]
                break
    if executable == "eval":
        return check_destructive(" ".join(args), depth + 1)[1]
    if executable == "rm":
        flags, targets, options = [], [], True
        for arg in args:
            if options and arg == "--":
                options = False
            elif options and arg.startswith("-"):
                flags.append(arg)
            else:
                targets.append(arg)
        short = short_flags(flags)
        recursive = "--recursive" in flags or bool(short.intersection("rR"))
        force = "--force" in flags or "f" in short
        if recursive and force and (not targets or not all(safe_cleanup_target(t) for t in targets)):
            return "rm -rf includes a target outside recognized temporary/build directories"
    if executable != "git":
        return ""
    while args and args[0].startswith("-"):
        flag = args.pop(0)
        if flag in GIT_VALUE_FLAGS and args:
            args.pop(0)
    if not args:
        return ""
    subcommand, *args = args
    option_args = args[:args.index("--")] if "--" in args else args
    flags, short = set(option_args), short_flags(option_args)
    if subcommand == "reset" and flags.intersection({"--hard", "--merge"}):
        return "git reset discards working tree changes"
    if subcommand == "restore" and (("--staged" not in flags and "S" not in short) or "--worktree" in flags or "W" in short):
        return "git restore can discard working tree changes"
    if subcommand == "checkout" and ("--" in args or "." in args):
        return "git checkout paths discards working tree changes"
    if subcommand == "clean" and ("--force" in flags or "f" in short) and "--dry-run" not in flags and "n" not in short:
        return "git clean -f removes untracked files"
    if subcommand == "push" and ("--force" in flags or "f" in short or any(a.startswith("+") for a in args)) and "--dry-run" not in flags and "n" not in short:
        return "git push force can overwrite remote history"
    if subcommand == "branch" and ("D" in short or (("d" in short or "--delete" in flags) and ("f" in short or "--force" in flags))):
        return "git branch force-deletes a branch without a merge check"
    if subcommand == "stash" and args and args[0] in {"drop", "clear"}:
        return "git stash drop/clear deletes saved changes"
    if subcommand == "rm" and "--cached" not in flags and "--dry-run" not in flags and "n" not in short:
        return "git rm deletes files from the working tree"
    return ""


def check_destructive(command: str, depth: int = 0) -> tuple[bool, str]:
    if depth > 8:
        return True, "nested shell command exceeds the guard's inspection limit"
    reasons: list[str] = []

    class Visitor(bashlex.ast.nodevisitor):
        def visitcommand(self, node, parts):
            reason = check_words([part.word for part in parts if part.kind == "word"], depth)
            if reason:
                reasons.append(reason)

    try:
        for tree in bashlex.parse(command):
            Visitor().visit(tree)
    except (bashlex.errors.ParsingError, NotImplementedError, ValueError):
        if re.search(r"\b(?:git|rm|eval)\b", command):
            return True, "cannot inspect this shell syntax; express the operation as a simpler command"
    return (True, reasons[0]) if reasons else (False, "")


def extract_command(data: dict) -> str:
    name = data.get("tool_name") or data.get("tool")
    if name not in {"Bash", "bash", "shell", "exec_command"}:
        return ""
    tool_input = data.get("tool_input") or data.get("input") or {}
    if isinstance(tool_input, dict):
        command = tool_input.get("command") or tool_input.get("cmd")
        if isinstance(command, str):
            return command
    command = data.get("command") or data.get("cmd")
    return command if isinstance(command, str) else ""


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            raise ValueError("expected a hook object")
    except (json.JSONDecodeError, ValueError):
        print("Git guard received an invalid hook payload", file=sys.stderr)
        return 2
    command = extract_command(data)
    if command:
        blocked, reason = check_destructive(command)
        if blocked:
            print(f"BLOCKED: {reason}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
