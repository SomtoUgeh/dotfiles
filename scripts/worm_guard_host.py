"""Optional, bounded workstation indicator checks; never execute inspected data.

All matches are review signals, not proof of compromise. Command lines and file
contents are never included in findings. Startup-file links are allowed only
when their resolved target remains inside the canonical home directory.
"""
import os
from pathlib import Path
import re
import selectors
import stat
import subprocess
import sys
import time

MAX_BYTES = 1024 * 1024
MAX_ENTRIES = 1000
COMMAND_TIMEOUT = 5


def _open_path(scanner, path, directory=False):
    """Walk without following symlinks, including intermediate components."""
    descriptor = None
    try:
        if not path.is_absolute() or ".." in path.parts:
            raise ValueError("absolute path without parent traversal required")
        descriptor = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
        for index, part in enumerate(path.parts[1:]):
            flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
            if index < len(path.parts) - 2 or directory:
                flags |= os.O_DIRECTORY
            child = os.open(part, flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        if not directory and not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise ValueError("not a regular file")
        result = descriptor
        descriptor = None
        return result
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        scanner.error(path, "workstation path inaccessible, symlinked, or unsupported; not inspected")
        return None
    finally:
        if descriptor is not None:
            os.close(descriptor)


def _read_file(scanner, path, home):
    try:
        before = path.lstat()
    except FileNotFoundError:
        return None
    except OSError:
        scanner.error(path, "startup file metadata inaccessible")
        return None
    try:
        resolved = path.resolve(strict=True)
        resolved.relative_to(home)
    except (OSError, RuntimeError, ValueError):
        scanner.error(path, "startup file target unavailable or outside home; not inspected")
        return None
    descriptor = _open_path(scanner, resolved)
    if descriptor is None:
        scanner.error(path, "startup file target could not be opened safely")
        return None
    with os.fdopen(descriptor, "rb") as handle:
        try:
            data = handle.read(MAX_BYTES + 1)
        except OSError:
            scanner.error(path, "workstation file read failed")
            return None
    if len(data) > MAX_BYTES:
        scanner.error(path, "workstation file exceeds inspection limit")
        return None
    try:
        after = path.lstat()
        metadata = ("st_dev", "st_ino", "st_mode", "st_size", "st_mtime_ns", "st_ctime_ns")
        if any(getattr(before, field) != getattr(after, field) for field in metadata) or path.resolve(strict=True) != resolved:
            raise ValueError("startup path changed")
    except (OSError, RuntimeError, ValueError):
        scanner.error(path, "startup file path changed during inspection")
        return None
    return data.decode("utf-8", errors="replace")


def _command(scanner, arguments):
    """Capture bounded output from fixed OS utilities, with no inherited env."""
    process = None
    try:
        process = subprocess.Popen(
            arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, cwd="/",
            env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"},
        )
        chunks = []
        total = 0
        deadline = time.monotonic() + COMMAND_TIMEOUT
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError
                for key, _ in selector.select(remaining):
                    chunk = os.read(key.fd, 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(chunk)
                    if total > MAX_BYTES:
                        raise ValueError("output limit")
                    chunks.append(chunk)
            code = process.wait(timeout=max(0.001, deadline - time.monotonic()))
        return code, b"".join(chunks).decode("utf-8", errors="replace")
    except (OSError, ValueError, TimeoutError, subprocess.TimeoutExpired):
        scanner.error(Path(arguments[0]), "workstation command unavailable, failed, timed out, or exceeded output limit")
        return None
    finally:
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait()
            if process.stdout is not None:
                process.stdout.close()


def _launch_items(scanner, directory):
    descriptor = _open_path(scanner, directory, directory=True)
    if descriptor is None:
        return
    try:
        with os.scandir(descriptor) as entries:
            for index, entry in enumerate(entries):
                if index >= MAX_ENTRIES:
                    scanner.error(directory, "launch-item inventory exceeds inspection limit")
                    break
                path = directory / entry.name
                if entry.is_symlink():
                    scanner.error(path, "symlinked launch item not inspected")
                elif not re.match(r"^(com\.(apple|google|docker|microsoft)(\.|$)|homebrew)", entry.name, re.I):
                    scanner.finding("host", path, None, "launch item outside common vendor names; review only, legitimate services can match")
    except OSError:
        scanner.error(directory, "launch-item inventory failed")
    finally:
        os.close(descriptor)


def scan_host(scanner, home: Path):
    """Inspect current-user startup files, process list, cron, and macOS jobs."""
    try:
        home = home.resolve(strict=True)
    except (OSError, RuntimeError):
        scanner.error(home, "workstation home unavailable; startup files not inspected")
        return
    descriptor = _open_path(scanner, home, directory=True)
    if descriptor is None:
        scanner.error(home, "workstation home unavailable; startup files not inspected")
        return
    os.close(descriptor)
    hidden_modules = home / ".node_modules"
    descriptor = _open_path(scanner, hidden_modules, directory=True)
    if descriptor is not None:
        os.close(descriptor)
        scanner.finding("host", hidden_modules, None, "hidden home node_modules directory; review persistence indicator, legitimate use possible")

    startup = re.compile(r"\b(?:curl|wget)\b.*(?:\||\beval\b)|\beval\b.*\bbase64\b", re.I)
    for name in (".bashrc", ".zshrc", ".profile", ".bash_profile"):
        path = home / name
        text = _read_file(scanner, path, home)
        if text is not None:
            for number, line in enumerate(text.splitlines(), 1):
                if not line.lstrip().startswith("#") and startup.search(line):
                    scanner.finding("host", path, number, "startup download/evaluation pattern; review only, legitimate setup can match")
                    break

    result = _command(scanner, ["/bin/ps", "-axo", "pid=,command="])
    if result is not None:
        code, output = result
        if code != 0:
            scanner.error(Path("/bin/ps"), "process inventory failed")
        else:
            node = re.compile(r"(?:^|[\s/])node\s")
            bootstrap = re.compile(r"global\[['\"](?:_V|!)['\"]\]")
            for line in output.splitlines():
                fields = line.strip().split(None, 1)
                if len(fields) != 2 or not fields[0].isdigit():
                    continue
                command = fields[1]
                opener = node.search(command)
                inline_eval = opener is not None and "-e" in command[opener.end():].split()
                if inline_eval or bootstrap.search(command):
                    scanner.finding("host", Path("/bin/ps"), None, "process PID " + fields[0] + " matches node eval/bootstrap pattern; review only; command redacted")

    result = _command(scanner, ["/usr/bin/crontab", "-l"])
    if result is not None:
        code, output = result
        if code == 1 and re.fullmatch(r"(?:crontab: )?no crontab for [^\r\n]+\n?", output.strip()):
            pass
        elif code != 0:
            scanner.error(Path("/usr/bin/crontab"), "current-user crontab inspection failed")
        else:
            for number, line in enumerate(output.splitlines(), 1):
                if not line.lstrip().startswith("#") and re.search(r"\b(?:node|curl|wget)\b", line):
                    scanner.finding("host", Path("/usr/bin/crontab"), number, "current-user cron entry invokes node/download tooling; review only; content redacted")
    if sys.platform == "darwin":
        for directory in (home / "Library/LaunchAgents", Path("/Library/LaunchAgents"), Path("/Library/LaunchDaemons")):
            _launch_items(scanner, directory)
