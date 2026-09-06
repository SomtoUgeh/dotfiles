"""Detector semantics and bounded runtime for inert adversarial text."""
import random
import re
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import worm_guard_patterns as patterns


class Results:
    root = Path("/fixture")

    def __init__(self):
        self.groups = {}

    def finding(self, group, path, line, reason):
        self.groups[group] = line

    def advisory(self, *args):
        pass


def scan(text):
    results = Results()
    patterns.scan_text(results, Path("/fixture/example.js"), text)
    return results.groups


class DetectorTests(unittest.TestCase):
    def test_adversarial_inputs_finish(self):
        # Child processes bound the test even if a quadratic regex regresses.
        # These inputs contain no executable payload, just repeated text.
        for expression in ("' ' * 250000", "'require(' * 100000", "'node ' * 100000"):
            with self.subTest(expression=expression):
                code = (
                    "import sys; sys.path.insert(0, " + repr(str(Path(__file__).parent)) + "); "
                    "from test_worm_guard_patterns import scan; scan(" + expression + ")"
                )
                subprocess.run([sys.executable, "-c", code], check=True, timeout=5)

    def test_signatures_and_line_numbers(self):
        cases = [
            ("padding", "x" + " " * 50 + "payload"),
            ("escaped-require", r'require("\u0068ttp")'),
            ("font-command", "node ./assets/font.woff2"),
            ("bootstrap-pattern", "global.r = require"),
        ]
        for group, value in cases:
            with self.subTest(group=group):
                self.assertEqual(scan("ordinary\n" + value).get(group), 2)
        self.assertNotIn("padding", scan("//" + " " * 80 + "comment"))
        self.assertNotIn("escaped-require", scan(r'require(foo) "\u0068"'))
        self.assertNotIn("font-command", scan("node file.js\nasset.woff2"))

    def test_campaign_and_generic_matches_remain_distinct(self):
        generic = scan("global.i = value; trongrid.io; node ordinary text .woff2")
        self.assertTrue({"bootstrap-pattern", "blockchain-rpc", "font-command"} <= generic.keys())
        self.assertFalse(patterns.CAMPAIGN_GROUPS.intersection(generic))
        exact = scan("A8-3997-1; 166.88.54.158")
        self.assertEqual(patterns.CAMPAIGN_GROUPS.intersection(exact), {"bootstrap", "network-ioc"})
        mixed = scan("global.r=require; A8-5657-1; trongrid.io; 166.88.54.158")
        self.assertTrue({"bootstrap", "bootstrap-pattern", "network-ioc", "blockchain-rpc"} <= mixed.keys())

    def test_cheap_prefilters_preserve_unicode_and_multiline_matches(self):
        self.assertIn("font-command", scan("node asset.woff2"))
        self.assertIn("escaped-require", scan(r'requıre("\u0068")'))
        self.assertIn("escaped-bootstrap", scan(r"\u0068\u0074\u0074\u0070" + "\n" + r"\u0063\u0068\u0069\u006c\u0064"))
        self.assertNotIn("font-command", scan("node asset_woff2"))
        self.assertNotIn("escaped-require", scan("require('plain')"))

    def test_equivalent_to_original_patterns(self):
        originals = {
            "padding": re.compile(r"[\t\v\f\r ]{50,}\S"),
            "escaped-require": re.compile(r"require\([^)]*\\u00[0-9a-fA-F]{2}", re.I),
            "font-command": re.compile(r"\bnode(?:\.exe)?\s+[^\r\n]*?\.(?:woff2?|ttf|otf|ttc|eot)\b", re.I),
        }
        rng = random.Random(123)
        pieces = ["require(", ")", r"\u0061", r"\u00xx", "node ", "NODE.exe ",
                  ".woff2", ".ttf_", "x", " ", " " * 60, "\t"]
        for _ in range(500):
            value = "".join(rng.choices(pieces, k=rng.randint(0, 30)))
            actual = scan(value)
            for group, pattern in originals.items():
                self.assertEqual(group in actual, bool(pattern.search(value)), (group, value))


if __name__ == "__main__":
    unittest.main()
