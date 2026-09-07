"""Inert parity fixtures from the inspected downloaded worm-scan.sh.

Source SHA-256: 22c30013fe4c9eb47976e21f142e4a8b128debaa2a07ef7e7db126dc28e0140f.
Only indicator strings are retained; no downloaded script is executed.
"""
from pathlib import Path
import unittest
from test_worm_guard_patterns import Results, patterns

MARKERS = ['rmcej%otb%', 'Cot%3t=shtP', '_$_1e42', "global['!']", "global['_V']", "global['r']", "global['m']", '2857687', '2667686', '1111436', '3896884']

C2 = ['api.trongrid.io', 'fullnode.mainnet.aptoslabs.com', 'bsc-dataseed.binance.org', 'bsc-rpc.publicnode.com', 'TMfKQEd7TJJa5xNZJZ2Lep838vrzrs7mAP', 'TXfxHUet9pJVU1BgVkBAbrES4YUc1nGzcG', '0xbe037400670fbf1c32364f762975908dc43eeb38759263e7dfcdabc76380811e', '0x3f0e5781d0855fb460661ac63257376db1941b2bb522499e4757ecb3ebd5dce3', '260120.vercel.app', 'default-configuration.vercel.app', 'vscode-settings-bootstrap.vercel.app', 'vscode-settings-config.vercel.app', 'vscode-bootstrapper.vercel.app', 'vscode-load-config.vercel.app', 'e9b53a7c-2342-4b15-b02d-bd8b8f6a03f9']

XORKEYS = ['2[gWfGj;<:-93Z^C', 'm6:tTh^D)cBz?NM]']

BADPKGS = ['tailwindcss-style-animate', 'tailwind-mainanimation', 'tailwind-autoanimation', 'tailwind-animationbased', 'tailwindcss-typography-style', 'tailwindcss-style-modify', 'tailwindcss-animate-style', 'html-to-gutenberg', 'fetch-page-assets', 'aes-decode-runner-pro', 'postcss-minify-selector', 'postcss-minify-selector-parser']


class ParityTests(unittest.TestCase):
    def test_all_downloaded_marker_network_and_key_strings(self):
        for marker in MARKERS + C2 + XORKEYS:
            with self.subTest(marker=marker):
                results = Results()
                patterns.scan_text(results, Results.root / "sample.txt", marker)
                self.assertTrue(results.groups)
                results = Results()
                patterns.scan_binary(results, Results.root / "sample.bin", b"\0" + marker.encode() + b"\0")
                self.assertIn("binary-indicator", results.groups)

    def test_all_downloaded_package_names_in_manifests_and_lockfiles(self):
        for package in BADPKGS:
            for filename in ("package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock"):
                with self.subTest(package=package, filename=filename):
                    results = Results()
                    patterns.scan_text(results, Results.root / filename, '"' + package + '": "1.0.0"')
                    self.assertIn("package", results.groups)


if __name__ == "__main__":
    unittest.main()
