#!/usr/bin/env bash
#
# scan_repo.sh [dir] [--include-generated] [--details]
# scan_repo.sh --selftest     run one inert smoke test in a temporary directory
#
# Exit codes: 0 no findings in scope, 1 matches/review signals, 2 incomplete.
# Default excludes untracked build caches; --include-generated reads them too.
# --details shows up to 20 locations per group (default: 3 review examples).
#
# Scans readable files, Git metadata, and stored blobs in discovered repositories.
# Missing history/objects or unreadable data make inspection incomplete. This is
# a known-indicator check, not proof that this Mac or remote refs are clean.

set -u

# Resolve installed symlinks before loading adjacent trusted helpers.
WORM_GUARD_ENTRY=$0
while [ -L "$WORM_GUARD_ENTRY" ]; do
  WORM_GUARD_PARENT=$(CDPATH= cd -- "$(dirname -- "$WORM_GUARD_ENTRY")" && pwd -P) || exit 2
  WORM_GUARD_ENTRY=$(/usr/bin/readlink "$WORM_GUARD_ENTRY") || exit 2
  case "$WORM_GUARD_ENTRY" in /*) ;; *) WORM_GUARD_ENTRY="$WORM_GUARD_PARENT/$WORM_GUARD_ENTRY" ;; esac
done
WORM_GUARD_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$WORM_GUARD_ENTRY")" && pwd -P) || exit 2
. "$WORM_GUARD_SCRIPT_DIR/worm_guard_runtime.sh" || exit 2

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }

run_scan() {
  local target="$1" script_dir script_path rc

  [ -d "$target" ] || { red "not a directory"; return 2; }
  target=$(CDPATH= cd -- "$target" && pwd -P) \
    || { red "scan target could not be resolved"; return 2; }
  script_dir=$WORM_GUARD_SCRIPT_DIR
  script_path="$script_dir/scan_repo.sh"
  worm_guard_runtime || return 2
  worm_guard_python - "$target" "$script_path" "${2:-0}" "${3:-0}" <<'PY'
import json
import importlib.util
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import threading
import time

module_path = Path(sys.argv[2]).parent / "worm_guard_patterns.py"
spec = importlib.util.spec_from_file_location("worm_guard_patterns", module_path)
patterns = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patterns)
FONT_SIGNATURES = patterns.FONT_SIGNATURES
TEXT_DECODE_ERROR = patterns.TEXT_DECODE_ERROR
decode_text = patterns.decode_text
scan_text = patterns.scan_text

MAX_TEXT_BYTES = 64 * 1024 * 1024
GIT_TIMEOUT_SECONDS = 300
SKIP_UNTRACKED_DIRS = {"node_modules", ".venv"}
GENERATED_DIRS = {".next", ".nuxt", ".svelte-kit", ".turbo", ".parcel-cache"}
GROUPS = (
    ("artifact", "Propagation artifact names"),
    ("artifact-path", "Propagation artifact filenames"),
    ("escaped-bootstrap", "Escaped bootstrap modules"),
    ("auto-run", "VS Code auto-run configuration"),
    ("bootstrap", "Campaign markers"),
    ("bootstrap-pattern", "Global assignment patterns"),
    ("padding", "Long whitespace padding in text"),
    ("long-line", "Very long single line in text"),
    ("escaped-require", "Unicode-escaped require"),
    ("network-ioc", "Campaign host, wallet, or XOR-key indicator"),
    ("blockchain-rpc", "Public blockchain RPC endpoints"),
    ("fake-font", "Invalid font signature"),
    ("gitignore", "Self-hiding or helper .gitignore entries"),
    ("font-command", "Node command and font extension on the same line"),
    ("commit-tamper", "Commit-tamper script marker"),
    ("package", "Known malicious npm dependency"),
    ("take-home", "Weaponized take-home marker"),
    ("oauth-token", "GitHub OAuth token-shaped secret"),
    ("timezone", "Local history timezone mismatch"),
    ("dropper-blob", "Known dropper blob prefix in local history"),
    ("git-command", "Git hooks and command-bearing configuration"),
)


def display_path(root, path):
    try:
        value = os.path.relpath(str(path), str(root))
    except (OSError, ValueError):
        value = str(path)
    return json.dumps(value, ensure_ascii=True)


class Scanner:
    def __init__(self, root, scanner_path, include_generated=False, details=False):
        self.root = root
        self.scanner_path = scanner_path
        self.include_generated = include_generated
        self.details = details
        self.excluded_generated_dirs = []
        self.findings = {key: [] for key, _ in GROUPS}
        self.finding_counts = {key: 0 for key, _ in GROUPS}
        self.errors = []
        self.error_count = 0
        self.advisories = []
        self.vscode_dirs = []
        self.files_inspected = 0
        self.text_files = 0
        self.binary_files = 0
        self.font_files = 0
        self.skipped_dependency_dirs = 0
        self.skipped_git_dirs = 0
        self.scanner_files_omitted = 0
        self.repositories = {}
        self.allowed_roots = [root]
        self.git_metadata_files = 0
        self.git_objects = 0
        self.git_blobs = 0
        self.git_stores = set()
        self.started = time.monotonic()
        self.progress_status = ("discovering files", root)
        self.progress_stop = threading.Event()
        self.progress_thread = None

    def progress(self, phase, path):
        self.progress_status = (phase, path)

    def start_progress(self):
        print("Starting scan: " + display_path(self.root.parent, self.root), file=sys.stderr, flush=True)
        self.progress_thread = threading.Thread(target=self.report_progress, daemon=True)
        self.progress_thread.start()

    def report_progress(self):
        while not self.progress_stop.wait(5):
            phase, path = self.progress_status
            message = ("Progress: " + phase
                       + "; files read=" + str(self.files_inspected)
                       + "; Git objects read=" + str(self.git_objects)
                       + "; elapsed=" + str(int(time.monotonic() - self.started)) + "s"
                       + "; path=" + display_path(self.root, path))
            try:
                print(message, file=sys.stderr, flush=True)
            except OSError:
                return

    def stop_progress(self):
        self.progress_stop.set()
        if self.progress_thread is not None:
            self.progress_thread.join()

    def finding(self, group, path, line, reason):
        self.finding_counts[group] += 1
        if len(self.findings[group]) < 20:
            self.findings[group].append((path, line, reason))

    def error(self, path, reason):
        self.error_count += 1
        if len(self.errors) < 50:
            self.errors.append((path, reason))

    def advisory(self, path, line, reason):
        if len(self.advisories) < 20:
            self.advisories.append((path, line, reason))


def git_environment():
    return {
        "HOME": os.environ.get("HOME", "/"),
        "PATH": os.environ["PATH"],
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_NO_LAZY_FETCH": "1",
        "GIT_ALLOW_PROTOCOL": "",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_PAGER": "cat",
        "GIT_TERMINAL_PROMPT": "0",
    }


def git_command(view, args, **kwargs):
    # The view has our own minimal config. Never let plumbing read the target's
    # includes, helpers, fsck overrides, or other executable configuration.
    command = [
        "git", "--no-pager", "--no-replace-objects",
        "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false",
        "-c", "log.showSignature=false", "-c", "protocol.allow=never",
        "--git-dir=" + str(view),
    ] + args
    return subprocess.Popen(command, cwd=str(view), env=git_environment(), **kwargs)


def git_capture(scanner, view, args, location, reason):
    with git_command(view, args, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
        try:
            output, errors = process.communicate(timeout=GIT_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            scanner.error(location, reason + " (time limit exceeded)")
            return None
    if process.returncode != 0 or errors:
        scanner.error(location, reason)
        return None
    return output


def tracked_files(scanner, view, worktree, gitdir, names):
    output = git_capture(scanner, view, ["ls-files", "--stage", "-z", "--cached", "--full-name"], gitdir, "tracked-file inventory failed")
    if output is None:
        return set()
    paths = set()
    for raw_name in output.split(b"\0"):
        if not raw_name:
            continue
        entry, separator, raw_path = raw_name.partition(b"\t")
        fields = entry.split()
        if not separator or len(fields) != 3 or not re.fullmatch(rb"[0-9a-f]{40}|[0-9a-f]{64}", fields[1]):
            scanner.error(gitdir, "tracked-file entry could not be parsed")
            continue
        name = Path(os.fsdecode(raw_path))
        if name.is_absolute() or ".." in name.parts:
            scanner.error(gitdir, "tracked path escapes repository root")
            continue
        if fields[0] != b"160000":
            names.setdefault(fields[1].decode("ascii"), set()).add(name.name)
        if worktree is None:
            continue
        candidate = worktree / name
        if fields[0] == b"160000":
            marker = candidate / ".git"
            if marker.exists() or marker.is_symlink():
                register_repository(scanner, marker, candidate)
            else:
                scanner.error(candidate, "submodule is not initialized; its files and objects are not inspected")
            continue
        paths.add(candidate)
    return paths


def register_repository(scanner, marker, worktree):
    try:
        if marker.is_file():
            data = read_file(scanner, marker, marker)
            if data is None:
                return
            if not data.startswith(b"gitdir: ") or b"\0" in data:
                scanner.error(marker, "invalid Git directory pointer")
                return
            marker = marker.parent / os.fsdecode(data[8:].rstrip(b"\r\n"))
        gitdir = marker.resolve(strict=True)
        if not gitdir.is_dir():
            raise ValueError()
        scanner.repositories.setdefault(gitdir, worktree)
        scanner.allowed_roots.append(gitdir)
    except (OSError, RuntimeError, ValueError):
        scanner.error(marker, "Git directory could not be resolved")


def filesystem_files(scanner):
    paths = set()

    def visit(directory, include_files=True):
        scanner.progress("discovering files", directory)
        # Also recognize bare repositories (and a .git directory passed directly).
        if (directory / "HEAD").is_file() and (directory / "objects").is_dir() and (directory / "refs").is_dir():
            register_repository(scanner, directory, None)
            return
        try:
            entries = list(os.scandir(str(directory)))
        except OSError:
            scanner.error(directory, "directory traversal failed")
            return
        entries.sort(key=lambda entry: os.fsencode(entry.name))
        for entry in entries:
            path = Path(entry.path)
            if entry.name == ".git":
                register_repository(scanner, path, directory)
                if not entry.is_dir(follow_symlinks=False):
                    paths.add(path)
                continue
            try:
                mode = entry.stat(follow_symlinks=False).st_mode
            except OSError:
                scanner.error(path, "path metadata could not be read")
                continue
            if stat.S_ISDIR(mode):
                if entry.name in GENERATED_DIRS and not scanner.include_generated:
                    scanner.excluded_generated_dirs.append(path)
                    # Still discover nested repositories. Their index entries
                    # and stored objects are added independently of this walk.
                    visit(path, include_files=False)
                    continue
                if entry.name in SKIP_UNTRACKED_DIRS:
                    scanner.skipped_dependency_dirs += 1
                    # Discover repositories even in excluded dependency trees;
                    # their tracked files and metadata still require inspection.
                    visit(path, include_files=False)
                    continue
                if entry.name == ".vscode":
                    scanner.vscode_dirs.append(path)
                visit(path, include_files)
            elif include_files:
                paths.add(path)
    visit(scanner.root)
    return paths


def resolve_read_path(scanner, path):
    try:
        metadata = path.lstat()
    except OSError:
        scanner.error(path, "file metadata could not be read")
        return None
    if stat.S_ISLNK(metadata.st_mode):
        try:
            resolved = path.resolve(strict=True)
            if not any(resolved.is_relative_to(root) for root in scanner.allowed_roots):
                raise ValueError()
            resolved_metadata = resolved.stat()
        except (OSError, RuntimeError, ValueError):
            scanner.error(path, "symlink could not be safely inspected")
            return None
        if not stat.S_ISREG(resolved_metadata.st_mode):
            scanner.error(path, "symlink target is not a regular file")
            return None
        return resolved
    if not stat.S_ISREG(metadata.st_mode):
        scanner.error(path, "unsupported non-regular path")
        return None
    return path


def read_file(scanner, display, path):
    flags = os.O_RDONLY
    if hasattr(os, "O_NONBLOCK"):
        flags |= os.O_NONBLOCK
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(str(path), flags)
    except OSError:
        scanner.error(display, "file could not be opened")
        return None
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            scanner.error(display, "unsupported non-regular file")
            return None
        with os.fdopen(descriptor, "rb", closefd=False) as handle:
            prefix = handle.read(8192)
            if before.st_size > MAX_TEXT_BYTES and b"\0" not in prefix:
                scanner.error(display, "text-like file exceeds inspection limit")
                return None
            chunks = [prefix]
            total = len(prefix)
            while total <= MAX_TEXT_BYTES:
                chunk = handle.read(min(1024 * 1024, MAX_TEXT_BYTES + 1 - total))
                if not chunk:
                    break
                chunks.append(chunk)
                total += len(chunk)
            data = b"".join(chunks)
        after = os.fstat(descriptor)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns
        ):
            scanner.error(display, "file changed while being inspected")
            return None
        if len(data) > MAX_TEXT_BYTES:
            scanner.error(display, "text-like file exceeds inspection limit")
            return None
        return data
    except OSError:
        scanner.error(display, "file read failed")
        return None
    finally:
        try:
            os.close(descriptor)
        except OSError:
            pass


def scan_file(scanner, path):
    scanner.progress("scanning files", path)
    try:
        if any(path.resolve(strict=True).samefile(trusted) for trusted in (scanner.scanner_path, module_path)):
            scanner.scanner_files_omitted += 1
            return
    except (OSError, RuntimeError):
        pass
    read_path = resolve_read_path(scanner, path)
    if read_path is None:
        return
    data = read_file(scanner, path, read_path)
    if data is None:
        return
    scanner.files_inspected += 1
    validator = FONT_SIGNATURES.get(path.suffix.lower())
    if validator is not None:
        scanner.font_files += 1
    patterns.scan_metadata(scanner, path, data)
    text = decode_text(data)
    if text is TEXT_DECODE_ERROR:
        scanner.error(path, "text encoding could not be decoded")
    elif text is not None:
        scanner.text_files += 1
        scan_text(scanner, path, text)
    else:
        scanner.binary_files += 1


def metadata_files(scanner, directory, hooks=False):
    paths = set()
    try:
        entries = list(directory.iterdir())
    except OSError:
        scanner.error(directory, "Git metadata directory could not be read")
        return paths
    for path in entries:
        try:
            mode = path.lstat().st_mode
            if stat.S_ISDIR(mode):
                if (path / "HEAD").is_file() and ((path / "objects").is_dir() or (path / "commondir").is_file()):
                    register_repository(scanner, path, None)
                    continue
                paths.update(metadata_files(scanner, path, hooks or path.name == "hooks"))
            else:
                # Packed/loose object encodings are inspected through Git below.
                # Unexpected files in the object directory still get a text scan.
                loose = path.parent.parent.name == "objects" and re.fullmatch(r"[0-9a-f]{2}", path.parent.name) and re.fullmatch(r"[0-9a-f]{38}|[0-9a-f]{62}", path.name)
                packed = path.parent.name == "pack" and path.parent.parent.name == "objects" and re.fullmatch(r"pack-[0-9a-f]+\.(pack|idx|rev|bitmap)", path.name)
                if (loose or packed) and stat.S_ISREG(mode):
                    if path.suffix == ".pack" and not path.with_suffix(".idx").is_file():
                        scanner.error(path, "pack has no index; stored objects may be omitted")
                    continue
                if path.suffix == ".promisor" and path.parent.name == "pack":
                    scanner.error(path, "partial clone/promisor pack; remote objects are not inspected")
                paths.add(path)
                if hooks and not path.name.endswith(".sample") and (mode & 0o111 or stat.S_ISLNK(mode)):
                    scanner.finding("git-command", path, None, "active Git hook; review executable content")
        except OSError:
            scanner.error(path, "Git metadata could not be inspected")
    return paths


def parse_git_config(scanner, path, view):
    read_path = resolve_read_path(scanner, path)
    if read_path is None:
        return []
    data = read_file(scanner, path, read_path)
    if data is None:
        return []
    # Parse a private bounded copy, never an untrusted include or named pipe.
    copy = view / "config-input"
    copy.write_bytes(data)
    output = git_capture(scanner, view, ["config", "--no-includes", "--null", "--file", str(copy), "--list"], path, "Git configuration could not be parsed")
    copy.unlink()
    if output is None:
        return []
    settings = []
    for record in output.split(b"\0"):
        if not record:
            continue
        key, separator, value = record.partition(b"\n")
        key = os.fsdecode(key).lower()
        value = os.fsdecode(value) if separator else "true"
        settings.append((key, value))
        if key == "include.path" or (key.startswith("includeif.") and key.endswith(".path")):
            scanner.error(path, "Git configuration includes are not followed; included settings remain uninspected")
        command = key in {"core.hookspath", "core.sshcommand", "core.gitproxy", "core.pager", "core.editor", "sequence.editor", "credential.helper", "gpg.program", "core.alternaterefscommand"}
        command |= key == "core.fsmonitor" and value.lower() not in {"false", "no", "off", "0"}
        command |= bool(re.fullmatch(r"(filter\..+\.(clean|smudge|process)|diff\..+\.(command|textconv)|merge\..+\.driver|gpg\..+\.program|pager\..+|credential\..+\.helper)", key))
        command |= key.startswith("alias.") and value.lstrip().startswith("!")
        if command and value:
            scanner.finding("git-command", path, None, "Git configuration can invoke an external command; review required")
        if key == "extensions.partialclone" or (key.startswith("remote.") and key.endswith(".promisor") and value.lower() not in {"false", "no", "off", "0"}):
            scanner.error(path, "partial clone configuration; remote objects are not inspected")
    return settings


def link_metadata(scanner, view, name, source, directory=False, required=False):
    try:
        metadata = source.lstat()
    except FileNotFoundError:
        if required:
            scanner.error(source, "required Git metadata is missing")
        return
    # Do not hand FIFOs, devices, or symbolic-link redirects to a Git subprocess.
    if not (stat.S_ISDIR(metadata.st_mode) if directory else stat.S_ISREG(metadata.st_mode)):
        scanner.error(source, "Git plumbing input is not a regular file or directory")
        return
    if directory and name == "objects":
        (view / name).symlink_to(source, target_is_directory=True)
    elif directory:
        (view / name).mkdir()
        for child in source.iterdir():
            link_metadata(scanner, view, name + "/" + child.name, child, child.is_dir() and not child.is_symlink())
    else:
        # Snapshot metadata, including HEAD and refs: Git rejects a redirected
        # HEAD/refs directory, and must never open a target FIFO or config include.
        data = read_file(scanner, source, source)
        if data is not None:
            (view / name).write_bytes(data)


def unquote_alternate(line):
    if not line.startswith(b'"'):
        return line
    # Git's C-style pathname quoting: literal UTF-8, standard escapes, or three
    # octal digits. This is data decoding, never shell/Python evaluation.
    escapes = {ord("a"): 7, ord("b"): 8, ord("t"): 9, ord("n"): 10,
               ord("v"): 11, ord("f"): 12, ord("r"): 13, 92: 92, 34: 34}
    result = bytearray()
    index = 1
    while index < len(line):
        value = line[index]
        index += 1
        if value == 34:
            if index != len(line):
                raise ValueError()
            return bytes(result)
        if value == 92:
            if index == len(line):
                raise ValueError()
            value = line[index]
            index += 1
            if value in escapes:
                value = escapes[value]
            elif 48 <= value <= 51 and index + 2 <= len(line) and all(48 <= digit <= 55 for digit in line[index:index + 2]):
                value = int(bytes([value]) + line[index:index + 2], 8)
                index += 2
            else:
                raise ValueError()
        result.append(value)
    raise ValueError()


def validate_object_store(scanner, root, visited, depth=0):
    try:
        if depth > 5 or not stat.S_ISDIR(root.lstat().st_mode):
            raise ValueError()
        root = root.resolve(strict=True)
        if root in visited:
            return True
        visited.add(root)
        valid = True
        pending = [root]
        while pending:
            directory = pending.pop()
            for path in directory.iterdir():
                mode = path.lstat().st_mode
                if stat.S_ISDIR(mode):
                    pending.append(path)
                elif not stat.S_ISREG(mode):
                    scanner.error(path, "unsafe special file or symlink in Git object storage")
                    valid = False
        alternates = root / "info" / "alternates"
        if alternates.exists() or alternates.is_symlink():
            data = read_file(scanner, alternates, alternates)
            if data is None:
                return False
            for line in data.split(b"\n"):
                if not line or line.startswith(b"#"):
                    continue
                raw = unquote_alternate(line)
                if not raw or b"\0" in raw:
                    raise ValueError()
                alternate = root / os.fsdecode(raw)
                if not validate_object_store(scanner, alternate, visited, depth + 1):
                    valid = False
        return valid
    except (OSError, RuntimeError, ValueError):
        scanner.error(root, "Git object storage or alternates could not be safely inspected")
        return False


def scan_git_objects(scanner, view, gitdir, hash_bytes, names):
    scanner.progress("reading Git object inventory", gitdir)
    inventory = git_capture(scanner, view, ["cat-file", "--batch-all-objects", "--batch-check"], gitdir, "stored-object inventory failed or omitted data")
    if inventory is None:
        return
    objects = []
    for line in inventory.splitlines():
        fields = line.split()
        if len(fields) != 3 or not re.fullmatch(rb"[0-9a-f]{%d}" % (hash_bytes * 2), fields[0]) or fields[1] not in {b"blob", b"tree", b"commit", b"tag"} or not fields[2].isdigit():
            scanner.error(gitdir, "stored-object inventory is malformed")
            return
        objects.append((fields[0], fields[1], int(fields[2])))
    # Read trees first so extension/name-dependent checks also cover deleted files.
    objects.sort(key=lambda item: item[1] != b"tree")
    with tempfile.TemporaryFile() as errors:
        with git_command(view, ["cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors) as process:
            completed = False
            watchdog = threading.Timer(GIT_TIMEOUT_SECONDS, process.kill)
            watchdog.daemon = True
            watchdog.start()
            try:
                for oid, kind, size in objects:
                    location = gitdir / "objects" / oid.decode("ascii")
                    scanner.progress("scanning stored Git objects", location)
                    if size > MAX_TEXT_BYTES:
                        scanner.error(location, "stored object exceeds inspection limit")
                        continue
                    process.stdin.write(oid + b"\n")
                    process.stdin.flush()
                    expected = oid + b" " + kind + b" " + str(size).encode("ascii") + b"\n"
                    if process.stdout.readline(256) != expected:
                        scanner.error(location, "stored object header is missing or malformed")
                        break
                    data = process.stdout.read(size)
                    if len(data) != size or process.stdout.read(1) != b"\n":
                        scanner.error(location, "stored object content is incomplete")
                        break
                    scanner.git_objects += 1
                    if kind == b"tree":
                        offset = 0
                        while offset < len(data):
                            end = data.find(b"\0", offset)
                            if end < 0 or end + 1 + hash_bytes > len(data):
                                scanner.error(location, "stored tree is malformed")
                                break
                            mode, separator, name = data[offset:end].partition(b" ")
                            child = data[end + 1:end + 1 + hash_bytes].hex()
                            if not separator or not name or b"/" in name or name in {b".", b".."}:
                                scanner.error(location, "stored tree filename is malformed")
                                break
                            if mode in {b"100644", b"100755", b"120000"}:
                                names.setdefault(child, set()).add(os.fsdecode(name))
                            offset = end + 1 + hash_bytes
                    elif kind == b"blob":
                        scanner.git_blobs += 1
                        if oid.startswith((b"5e226620", b"934d5554")):
                            scanner.finding("dropper-blob", location, None, "known dropper blob prefix exists in local storage")
                        text = decode_text(data)
                        if text is TEXT_DECODE_ERROR:
                            scanner.error(location, "stored text encoding could not be decoded")
                            continue
                        for name in sorted(names.get(oid.decode("ascii"), {"unreferenced-blob"})):
                            display = location / name
                            patterns.scan_metadata(scanner, display, data)
                            if text is not None:
                                scan_text(scanner, display, text)
                else:
                    completed = True
            except (OSError, ValueError):
                scanner.error(gitdir, "stored-object reader failed")
            finally:
                watchdog.cancel()
                process.stdin.close()
                # There is at most one bounded request outstanding. On framing
                # failure stop the reader instead of waiting on a full pipe.
                if completed:
                    try:
                        if process.wait(timeout=10) != 0:
                            scanner.error(gitdir, "stored-object reader exited unsuccessfully")
                    except subprocess.TimeoutExpired:
                        scanner.error(gitdir, "stored-object reader did not finish")
                        process.kill()
                        process.wait()
                else:
                    process.kill()
                    process.wait()
        errors.seek(0)
        if errors.read(1):
            scanner.error(gitdir, "stored-object reader reported omitted or corrupt data")


def scan_repository(scanner, gitdir, worktree):
    scanner.progress("checking Git metadata", gitdir)
    common = gitdir
    pointer = gitdir / "commondir"
    if pointer.exists() or pointer.is_symlink():
        data = read_file(scanner, pointer, pointer)
        try:
            if data is None or not data.rstrip(b"\r\n") or b"\0" in data:
                raise ValueError()
            common = (gitdir / os.fsdecode(data.rstrip(b"\r\n"))).resolve(strict=True)
            if not common.is_dir():
                raise ValueError()
        except (OSError, RuntimeError, ValueError):
            scanner.error(pointer, "shared Git directory could not be resolved")
            return set()
    scanner.allowed_roots.append(common)
    paths = metadata_files(scanner, gitdir)
    if common != gitdir:
        paths.update(metadata_files(scanner, common))
    scanner.git_metadata_files += len(paths)
    with tempfile.TemporaryDirectory(prefix="worm-guard-git-") as temporary:
        view = Path(temporary)
        (view / "config").write_text("[core]\nrepositoryFormatVersion = 0\nbare = true\n")
        settings = []
        for config in dict.fromkeys([common / "config", common / "config.worktree", gitdir / "config.worktree"]):
            if config.exists() or config.is_symlink():
                settings.extend((key, value, config) for key, value in parse_git_config(scanner, config, view))
        for key, value, config_path in settings:
            if key == "core.repositoryformatversion" and value not in {"0", "1"}:
                scanner.error(common / "config", "unsupported repository format")
            if key.startswith("extensions.") and key not in {"extensions.objectformat", "extensions.worktreeconfig", "extensions.partialclone", "extensions.refstorage"}:
                scanner.error(common / "config", "unsupported repository extension")
            if key == "core.hookspath" and value and value != "/dev/null":
                hooks = Path(os.path.expanduser(value))
                if not hooks.is_absolute():
                    base = worktree or gitdir
                    if common != gitdir and config_path == common / "config.worktree":
                        base = common.parent if common.name == ".git" else common
                    hooks = base / hooks
                try:
                    if hooks.exists():
                        hooks = hooks.resolve(strict=True)
                        scanner.allowed_roots.append(hooks)
                        paths.update(metadata_files(scanner, hooks, hooks=True))
                except (OSError, RuntimeError):
                    scanner.error(common / "config", "configured Git hooks directory could not be inspected")
        config = {key: value for key, value, _ in settings}
        object_format = config.get("extensions.objectformat", "sha1").lower()
        if object_format not in {"sha1", "sha256"} or config.get("extensions.refstorage", "files").lower() != "files":
            scanner.error(common / "config", "unsupported Git object or reference storage format")
            return paths
        if object_format == "sha256":
            (view / "config").write_text("[core]\nrepositoryFormatVersion = 1\nbare = true\n[extensions]\nobjectFormat = sha256\n")
        stores = set()
        if not validate_object_store(scanner, common / "objects", stores):
            return paths
        for store in stores - {common / "objects"}:
            scanner.allowed_roots.append(store)
            paths.update(metadata_files(scanner, store))
        for name, source, directory, required in [
            ("HEAD", gitdir / "HEAD", False, True),
            ("index", gitdir / "index", False, False),
            ("refs", common / "refs", True, True),
            ("objects", common / "objects", True, True),
            ("packed-refs", common / "packed-refs", False, False),
            ("shallow", common / "shallow", False, False),
            ("logs", gitdir / "logs", True, False),
        ]:
            link_metadata(scanner, view, name, source, directory, required)
        for shared_index in gitdir.glob("sharedindex.*"):
            link_metadata(scanner, view, shared_index.name, shared_index)
        if (common / "shallow").exists():
            scanner.error(common / "shallow", "shallow clone; omitted history is not inspected")
        names = {}
        paths.update(tracked_files(scanner, view, worktree, gitdir, names))
        log = git_capture(scanner, view, ["log", "--no-show-signature", "--all", "-n", "500", "--format=%H%x00%an%x00%cn%x00%ai%x00%ci"], gitdir, "last-500-commit metadata check failed")
        if log is not None:
            for raw_line in log.splitlines():
                fields = raw_line.split(b"\0")
                if len(fields) != 5:
                    scanner.error(gitdir, "commit metadata could not be parsed")
                    break
                commit, author, committer, author_date, committer_date = fields
                if author == committer and author_date.rsplit(b" ", 1)[-1] != committer_date.rsplit(b" ", 1)[-1]:
                    scanner.finding("timezone", gitdir, None, "same-name author/committer offsets differ at commit " + commit[:12].decode("ascii", "replace"))
        scanner.progress("checking Git integrity", gitdir)
        with git_command(view, ["fsck", "--full", "--no-dangling", "--no-progress"], stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
            try:
                output, errors = process.communicate(timeout=GIT_TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()
                scanner.error(gitdir, "Git integrity check exceeded its time limit")
                output, errors = b"", b""
        benign_notices = (b"notice: HEAD points to an unborn branch", b"notice: No default references")
        diagnostics = [line for line in (output + errors).splitlines() if line and not line.startswith(benign_notices)]
        if process.returncode != 0 or diagnostics:
            scanner.error(gitdir, "Git integrity check failed; objects or references are missing, corrupt, or unreadable")
        # Each worktree has a separate index: its staged-only blobs need that
        # index's names even when several worktrees share the same object store.
        scan_git_objects(scanner, view, common, 32 if object_format == "sha256" else 20, names)
    return paths


def print_item(scanner, item):
    path, line, reason = item
    location = "path=" + display_path(scanner.root, path)
    if line is not None:
        location += " line=" + str(line)
    print("    " + location + " reason=" + reason)


def render(scanner, history_checked):
    print("\033[1mScanning: " + json.dumps(str(scanner.root), ensure_ascii=True) + "\033[0m")
    campaign = sum(count for key, count in scanner.finding_counts.items() if key in patterns.CAMPAIGN_GROUPS)
    total = sum(scanner.finding_counts.values())
    review = total - campaign
    print("Campaign matches: " + str(campaign) + "; Review signals: " + str(review)
          + "; Inspection errors: " + str(scanner.error_count))
    if scanner.error_count:
        print("Inspection incomplete; " + str(scanner.error_count) + " error(s).")
    elif campaign:
        print("Campaign signatures matched; investigate the locations below.")
    elif review:
        print("No campaign signatures matched. Review signals alone do not establish infection.")
    else:
        print("No known worm indicators found in the files inspected.")
    print("Matches do not establish execution or infection. This is a check of the stated scope, not all malware.")
    print(
        "Coverage: files=" + str(scanner.files_inspected)
        + " text=" + str(scanner.text_files)
        + " binary=" + str(scanner.binary_files)
        + " fonts=" + str(scanner.font_files)
        + " skipped-dependency-dirs=" + str(scanner.skipped_dependency_dirs)
        + " skipped-git-metadata-dirs=" + str(scanner.skipped_git_dirs)
        + " trusted-scanner-files-omitted=" + str(scanner.scanner_files_omitted)
    )
    print("Git coverage: repositories=" + str(len(scanner.repositories))
          + " metadata-files=" + str(scanner.git_metadata_files)
          + " objects=" + str(scanner.git_objects) + " blobs=" + str(scanner.git_blobs))
    if history_checked:
        print("History scope: all locally stored objects, including unreachable blobs; commit metadata limited to the last 500 commits per repository.")
    else:
        print("Git history was not checked: no repositories were discovered.")
    print("Scope: dependency directories are excluded unless tracked; remote-only/pruned objects and configuration includes are not inspected.")
    print("Generated directories excluded: " + str(len(scanner.excluded_generated_dirs)))
    for path in scanner.excluded_generated_dirs:
        print("    path=" + display_path(scanner.root, path))
    if not scanner.include_generated:
        print("Build-cache scope: untracked files under " + ", ".join(sorted(GENERATED_DIRS))
              + " are excluded. Tracked paths and stored Git objects remain inspected.")
        print("Use --include-generated to inspect those files; large or changing build outputs may be incomplete.")
    for is_campaign, heading in ((True, "Campaign match locations"), (False, "Review signals (not proof of infection)")):
        groups = [(key, title) for key, title in GROUPS
                  if (key in patterns.CAMPAIGN_GROUPS) == is_campaign and scanner.finding_counts[key]]
        if not groups:
            continue
        print("\n" + heading)
        for key, title in groups:
            count = scanner.finding_counts[key]
            print("  " + title + ": " + str(count))
            limit = 20 if scanner.details or is_campaign else 3
            items = scanner.findings[key][:limit]
            for item in items:
                print_item(scanner, item)
            if count > len(items):
                print("    " + str(count - len(items)) + " more location(s); "
                      + ("report capped at 20 per group" if scanner.details else "use --details for up to 20 per group"))
    if scanner.advisories:
        print("\ncreateRequire: advisory only; createRequire is legitimate without a correlated indicator")
        if scanner.details:
            for item in scanner.advisories:
                print_item(scanner, item)
    if scanner.errors:
        print("\n\033[1mInspection errors\033[0m")
        for path, reason in scanner.errors:
            print("    path=" + display_path(scanner.root, path) + " reason=" + reason)
        if scanner.error_count > len(scanner.errors):
            print("    " + str(scanner.error_count - len(scanner.errors)) + " additional error(s) omitted")

    if scanner.error_count:
        return 20
    if total:
        return 10
    return 0


def main():
    if len(sys.argv) != 5:
        print("inspection incomplete: invalid scanner invocation", file=sys.stderr)
        return 20
    try:
        root = Path(sys.argv[1]).resolve(strict=True)
        scanner_path = Path(sys.argv[2]).resolve(strict=True)
    except (OSError, RuntimeError):
        print("inspection incomplete: path resolution failed", file=sys.stderr)
        return 20
    if not root.is_dir() or not scanner_path.is_file():
        print("inspection incomplete: invalid scanner path", file=sys.stderr)
        return 20
    scanner = Scanner(root, scanner_path, sys.argv[3] == "1", sys.argv[4] == "1")
    try:
        scanner.start_progress()
        paths = filesystem_files(scanner)
        processed = set()
        while pending := set(scanner.repositories) - processed:
            for gitdir in sorted(pending):
                processed.add(gitdir)
                paths.update(scan_repository(scanner, gitdir, scanner.repositories[gitdir]))
        for path in sorted(paths, key=lambda value: os.fsencode(str(value))):
            scan_file(scanner, path)
    except (KeyboardInterrupt, SystemExit):
        raise
    except Exception:
        print("inspection incomplete: unexpected scanner failure", file=sys.stderr)
        return 20
    finally:
        scanner.stop_progress()
    return render(scanner, bool(scanner.repositories))


try:
    raise SystemExit(main())
except KeyboardInterrupt:
    print("inspection incomplete: scan interrupted; no complete result.", file=sys.stderr, flush=True)
    raise SystemExit(20)
PY
  rc=$?
  case "$rc" in
    0)  return 0 ;;
    10) return 1 ;;
    20) return 2 ;;
    *)  red "inspection incomplete: scanner runtime failed"; return 2 ;;
  esac
}

selftest() {
  local sample output rc result=1
  sample=$(mktemp -d "${TMPDIR:-/tmp}/scan-repo-selftest.XXXXXX") \
    || { red "selftest could not create a temporary directory"; return 2; }
  output="$sample/output"
  trap 'rm -rf -- "$sample"' EXIT HUP INT TERM
  mkdir -p "$sample/repo/.vscode" || return 2
  printf '{"tasks":[{"runOptions":{"runOn":"folderOpen"}}]}\n' > "$sample/repo/.vscode/tasks.json"
  printf 'module.exports={}%*sglobal.%s="A8-%s-1"\n' 60 '' 'i' '3997' > "$sample/repo/config"
  run_scan "$sample/repo" > "$output" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'editor task can run' "$output" && grep -q 'known bootstrap signature' "$output"; then
    grn "SELFTEST PASS — inert auto-run and bootstrap fixtures were detected."
    result=0
  else
    red "SELFTEST FAIL — scanner did not detect the inert fixtures (exit $rc)."
    sed -n '1,240p' "$output"
  fi
  rm -rf -- "$sample"
  trap - EXIT HUP INT TERM
  return "$result"
}

main() {
  local target=. target_set=0 include_generated=0 details=0
  if [ "$#" -eq 0 ]; then sed -n '2,14p' "$0"; return 0; fi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --selftest) [ "$#" -eq 1 ] && [ "$target_set" -eq 0 ] || return 2; selftest; return $? ;;
      --help|-h) sed -n '2,14p' "$0"; return 0 ;;
      --include-generated) include_generated=1 ;;
      --details) details=1 ;;
      --) shift; [ "$#" -eq 1 ] && [ "$target_set" -eq 0 ] || return 2; target=$1; target_set=1 ;;
      -*) red "inspection incomplete: unknown option $1"; return 2 ;;
      *) [ "$target_set" -eq 0 ] || { red 'inspection incomplete: expected one directory'; return 2; }; target=$1; target_set=1 ;;
    esac
    shift
  done
  run_scan "$target" "$include_generated" "$details"
}

main "$@"
