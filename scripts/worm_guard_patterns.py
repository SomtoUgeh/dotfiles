"""Shared inert-byte signatures for local and GitHub scans (Python 3.9+).

Collectors own scope, reads and verdicts. This module never executes scanned data.
"""
import codecs
import os
from pathlib import Path
import re
import sys

FONT_SIGNATURES = {
    ".woff2": lambda data: data.startswith(b"wOF2"),
    ".woff": lambda data: data.startswith(b"wOFF"),
    ".ttf": lambda data: data.startswith((b"\x00\x01\x00\x00", b"true", b"typ1")),
    ".otf": lambda data: data.startswith((b"OTTO", b"\x00\x01\x00\x00", b"true", b"typ1")),
    ".ttc": lambda data: data.startswith(b"ttcf"),
    ".eot": lambda data: len(data) >= 36 and data[34:36] == b"LP",
}
TEXT_DECODE_ERROR = object()
CAMPAIGN_GROUPS = frozenset({
    "artifact", "artifact-path", "bootstrap", "network-ioc", "package",
    "take-home", "dropper-blob",
})
GENERATED_NAMES = (
    re.compile(r"\.min\.", re.IGNORECASE),
    re.compile(r"-lock\.json$", re.IGNORECASE),
    re.compile(r"(^|/)yarn\.lock$", re.IGNORECASE),
    re.compile(r"(^|/)pnpm-lock\.yaml$", re.IGNORECASE),
    re.compile(r"(?:^|/)bundle\.[^.]+$|\.bundle\.", re.IGNORECASE),
    re.compile(r"\.map$", re.IGNORECASE),
)

def decode_text(data):
    encodings = (
        (codecs.BOM_UTF32_LE, "utf-32"), (codecs.BOM_UTF32_BE, "utf-32"),
        (codecs.BOM_UTF16_LE, "utf-16"), (codecs.BOM_UTF16_BE, "utf-16"),
        (codecs.BOM_UTF8, "utf-8-sig"),
    )
    for bom, encoding in encodings:
        if data.startswith(bom):
            try:
                return data.decode(encoding)
            except UnicodeError:
                return TEXT_DECODE_ERROR
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeError:
        controls = sum(byte < 32 and byte not in b"\t\n\r\f\b" for byte in data)
        if data and controls / len(data) > 0.02:
            return None
        return data.decode("latin-1")


def first_line(lines, pattern):
    pattern = re.compile(pattern.pattern, pattern.flags | re.IGNORECASE)
    for number, line in enumerate(lines, 1):
        if pattern.search(line):
            return number
    return None


def escaped_require_line(lines):
    # Remember the first opener until a closing parenthesis. Retrying a greedy
    # suffix at every nested require( makes missing escapes quadratic.
    tokens = re.compile(r"require\(|\)|\\u00[0-9a-f]{2}", re.IGNORECASE)
    for number, value in enumerate(lines, 1):
        opened = False
        for match in tokens.finditer(value):
            token = match.group()
            if token == ")":
                opened = False
            elif token.startswith("\\"):
                if opened:
                    return number
            else:
                opened = True
    return None


def font_command_line(lines):
    command = re.compile(r"\bnode(?:\.exe)?\s", re.IGNORECASE)
    extension = re.compile(r"\.(?:woff2?|ttf|otf|ttc|eot)\b", re.IGNORECASE)
    for number, value in enumerate(lines, 1):
        # Lines have no CR/LF. Any extension after the earliest command also
        # satisfies the original command-plus-arbitrary-suffix expression.
        match = command.search(value)
        if match is not None and extension.search(value, match.end()):
            return number
    return None


def scan_text(scanner, path, text):
    relative = os.path.relpath(str(path), str(scanner.root))
    lines = text.splitlines()
    suffix = path.suffix.lower()

    bootstrap_pattern = re.compile(
        r"global\[['\"](?:!|_V|_t_t|r|m)['\"]\]|global\.i\s*=|"
        r"global\.r\s*=\s*require"
    )
    bootstrap = re.compile(
        r"A8-(?:3997|5657)-1|"
        + re.escape("rmcej" + "%otb%") + "|" + re.escape("Cot" + "%3t=shtP") + r"|_\$_1e42"
    )
    blockchain_rpc = re.compile(
        r"trongrid\.io|bsc-" + r"dataseed|bsc-rpc\.publicnode\.com|"
        r"fullnode\.mainnet\.aptoslabs\.com"
    )
    network = re.compile(
        r"166\.88\.54\.158|"
        r"(?:default-configuration|vscode-settings-bootstrap|vscode-settings-config|"
        r"vscode-bootstrapper|vscode-load-config|260120)\.vercel\.app|"
        + re.escape("TMfKQEd7TJJa5xNZ" + "JZ2Lep838vrzrs7mAP") + "|"
        + re.escape("TXfxHUet9pJVU1Bg" + "VkBAbrES4YUc1nGzcG") + "|"
        + re.escape("0xbe037400670fbf1c32364f762975908d" + "c43eeb38759263e7dfcdabc76380811e") + "|"
        + re.escape("0x3f0e5781d0855fb460661ac63257376d" + "b1941b2bb522499e4757ecb3ebd5dce3") + "|"
        + re.escape("2[gWfGj;<:-93Z" + "^C") + "|" + re.escape("m6:tTh^D)cBz?NM" + "]")
    )
    package = re.compile(
        r"tailwindcss-(?:style-animate|typography-style|style-modify|animate-style)|"
        r"tailwind-(?:mainanimation|autoanimation|animationbased)|"
        r"postcss-minify-selector-parser|html-to-gutenberg|fetch-page-assets|aes-decode-runner-pro"
    )

    artifact = re.compile(r"branch_" + r"structure\.json|temp_" + r"(?:auto|interactive)_push\.(?:bat|sh)|truffle" + "Secrets", re.IGNORECASE)
    line = first_line(lines, artifact)
    if line is not None:
        scanner.finding("artifact", path, line, "known propagation artifact name")
    if "\\" in text and re.search(r"\\u0068" + r"\\u0074\\u0074\\u0070|\\x68" + r"\\x74\\x74\\x70", text, re.IGNORECASE) and re.search(r"\\u0063" + r"\\u0068\\u0069\\u006c\\u0064|\\x63" + r"\\x68\\x69\\x6c\\x64", text, re.IGNORECASE):
        scanner.finding("escaped-bootstrap", path, 1, "escaped http and child-process module names occur together")
    line = first_line(lines, bootstrap)
    if line is not None:
        scanner.finding("bootstrap", path, line, "known bootstrap signature")
    line = first_line(lines, bootstrap_pattern)
    if line is not None:
        scanner.finding("bootstrap-pattern", path, line, "global assignment pattern; legitimate code can match")
    for number, value in enumerate(lines, 1):
        stripped = value.lstrip()
        if stripped.startswith(("#", "//", "*", "/*")):
            continue
        # Try each whitespace run once, including when it has no following text.
        if re.search(r"(?<![\t\v\f\r ])[\t\v\f\r ]{50,}\S", value):
            scanner.finding("padding", path, number, "50 or more whitespace characters before content")
            break
    if not any(pattern.search(relative) for pattern in GENERATED_NAMES):
        for number, value in enumerate(lines, 1):
            if len(value) > 2000:
                scanner.finding("long-line", path, number, "line exceeds 2000 characters")
                break
    line = escaped_require_line(lines) if "\\" in text else None
    if line is not None:
        scanner.finding("escaped-require", path, line, "require contains a Unicode escape")
    line = first_line(lines, network)
    if line is not None:
        scanner.finding("network-ioc", path, line, "known campaign indicator")
    line = first_line(lines, blockchain_rpc)
    if line is not None:
        scanner.finding("blockchain-rpc", path, line, "public blockchain endpoint; legitimate code can match")

    if path.name == ".gitignore":
        ignore_names = {"temp_" + "auto_push.bat", "temp_" + "interactive_push.bat", "branch_" + "structure.json"}
        for number, value in enumerate(lines, 1):
            stripped = value.strip()
            if stripped in ignore_names or stripped == ".gitignore":
                scanner.finding("gitignore", path, number, "known self-hiding or helper entry")
                break

    line = first_line(lines, re.compile(r"\bcreateRequire\s*\(\s*import\.meta\.url\s*\)"))
    if line is not None:
        scanner.advisory(path, line, "createRequire in ESM is legitimate by itself; correlate with findings")

    task_pattern = r'"runOn"\s*:\s*"folder' + r'Open"|"task\.allowAutomaticTasks"\s*:\s*true'
    if ".vscode" in path.parts or suffix in {".json", ".jsonc"}:
        task_pattern = r"folder" + r"Open|(?:task\.)?allowAutomaticTasks['\"]?\s*:\s*true"
    line = first_line(lines, re.compile(task_pattern))
    if line is not None:
        scanner.finding("auto-run", path, line, "editor task can run when the folder opens")
    line = font_command_line(lines) if "." in text else None
    if line is not None:
        scanner.finding("font-command", path, line, "node command text and a font extension occur on the same line; execution is not established")

    line = first_line(lines, re.compile(r"\bLAST_" + r"COMMIT_DATE\b"))
    if line is not None and suffix in {".bat", ".ps1", ".sh"}:
        scanner.finding("commit-tamper", path, line, "commit-date rewrite marker")

    if path.name in {"package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml"}:
        line = first_line(lines, package)
        if line is not None:
            scanner.finding("package", path, line, "known malicious package name")
    line = first_line(lines, re.compile(re.escape("e9b53a7c-2342-4b15" + "-b02d-bd8b8f6a03f9")))
    if line is not None:
        scanner.finding("take-home", path, line, "known weaponized sample identifier")
    line = first_line(lines, re.compile(r"gh[ou]_[A-Za-z0-9]{36}"))
    if line is not None:
        scanner.finding("oauth-token", path, line, "token-shaped secret; revoke the grant")



def scan_metadata(scanner, path, data):
    """Filename and font checks also apply to binary files and stored blobs."""
    name = path.name.lower()
    if re.fullmatch(r"temp_" + r"(?:auto|interactive)_push\.(?:bat|sh)|branch_" + r"structure\.json|truffle" + r"secrets.*", name):
        scanner.finding("artifact-path", path, 1, "known propagation artifact filename")
    validator = FONT_SIGNATURES.get(path.suffix.lower())
    if validator is not None and not validator(data):
        scanner.finding("fake-font", path, 1, "content does not match the font extension")


class RemoteResults:
    root = Path("/")

    def finding(self, group, path, line, reason):
        labels = {"bootstrap": "worm-marker", "padding": "hidden-padding", "artifact": "worm-artifact", "artifact-path": "worm-artifact-path"}
        print("finding\t" + labels.get(group, group) + "\t" + reason)

    def advisory(self, path, line, reason):
        print("review\tcreateRequire\t" + reason)


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in {"text", "metadata"}:
        return 2
    mode, name, source = sys.argv[1:]
    try:
        with open(source, "rb") as handle:
            data = handle.read(36) if mode == "metadata" else handle.read()
        path = Path(name)
        if mode == "metadata":
            scan_metadata(RemoteResults(), path, data)
        else:
            text = decode_text(data)
            if text is TEXT_DECODE_ERROR or text is None:
                return 2
            scan_text(RemoteResults(), path, text)
        return 0
    except (OSError, ValueError):
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
