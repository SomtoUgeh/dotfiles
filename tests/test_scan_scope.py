"""Local scan scope and useful verdicts through the public shell entrypoint."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MARKER = 'A8-' + '5657-1'


class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
        return path

    def git(self, *args, directory=None):
        env = dict(os.environ, GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
                   GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.test',
                   GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.test')
        subprocess.run(['git', '-c', 'init.templateDir=', '-c', 'core.hooksPath=/dev/null',
                        '-c', 'commit.gpgSign=false', *args], cwd=directory or self.root,
                       env=env, check=True, capture_output=True)

    def scan(self, *args, expected):
        result = subprocess.run(['/bin/bash', str(ROOT / 'scripts/scan_repo.sh'),
                                 str(self.root), *args], capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, expected, output)
        return output

    def test_default_omits_generated_files_and_names_the_scope(self):
        self.write('src/app.js', 'ordinary source')
        self.write('app/.next/cache/output.js', MARKER)
        output = self.scan(expected=0)
        self.assertIn('Result: NO KNOWN INDICATORS', output)
        self.assertIn('(exit 0)', output)
        self.assertIn('Generated directories excluded: 1', output)
        self.assertIn('app/.next', output)
        self.assertIn('--include-generated', output)
        self.assertNotIn('known bootstrap signature', output)

    def test_include_generated_detects_known_marker(self):
        self.write('.next/cache/output.js', MARKER)
        output = self.scan('--include-generated', expected=1)
        self.assertIn('Result: REVIEW NEEDED', output)
        self.assertIn('(exit 1)', output)
        self.assertIn('Scanner rules, test samples and documentation', output)
        self.assertIn('known bootstrap signature', output)
        self.assertIn('Generated directories excluded: 0', output)

    def test_tracked_generated_files_cannot_be_hidden(self):
        self.git('init', '-q')
        self.write('.next/runner', MARKER)
        self.git('add', '.next/runner')
        output = self.scan(expected=1)
        self.assertIn('known bootstrap signature', output)

    def test_historical_generated_files_cannot_be_hidden(self):
        self.git('init', '-q')
        path = self.write('.next/runner', MARKER)
        self.git('add', '.')
        self.git('commit', '-qm', 'inert marker')
        path.write_text('ordinary replacement')
        self.git('add', '.')
        self.git('commit', '-qm', 'replacement')
        output = self.scan(expected=1)
        self.assertIn('known bootstrap signature', output)

    def test_nested_repository_in_generated_directory_is_inspected(self):
        path = self.write('.next/nested/runner', MARKER)
        self.git('init', '-q', directory=path.parent)
        self.git('add', 'runner', directory=path.parent)
        output = self.scan(expected=1)
        self.assertIn('known bootstrap signature', output)

    def test_source_directories_and_arbitrary_ignored_files_still_scan(self):
        self.git('init', '-q')
        self.write('.gitignore', 'build/\n')
        self.write('build/app.js', MARKER)
        output = self.scan(expected=1)
        self.assertIn('known bootstrap signature', output)

    def test_review_only_is_not_reported_as_campaign_detection(self):
        self.write('ordinary.js', 'x' * 2100)
        output = self.scan(expected=1)
        self.assertIn('Campaign matches: 0', output)
        self.assertIn('Review signals: 1', output)
        self.assertIn('do not establish infection', output)
        self.assertIn('other signals need context', output)
        self.assertNotIn('matches contain known worm-related markers', output)
        self.assertNotIn('indicator(s) found', output)

    def test_generic_patterns_remain_review_only_and_do_not_claim_execution(self):
        self.write('ordinary.js', 'global.i = value; trongrid.io; node ordinary text .woff2')
        output = self.scan(expected=1)
        self.assertIn('Campaign matches: 0; Review signals: 3', output)
        self.assertIn('execution is not established', output)

    def test_mixed_exact_and_generic_matches_are_both_visible(self):
        self.write('example.js', MARKER + '; global.i = value;')
        output = self.scan(expected=1)
        self.assertIn('Campaign matches: 1; Review signals: 1', output)
        self.assertIn('known bootstrap signature', output)
        self.assertIn('legitimate code can match', output)

    def test_incomplete_takes_precedence_over_findings(self):
        self.write('runner', MARKER)
        (self.root / 'missing').symlink_to(self.root / 'absent')
        output = self.scan(expected=2)
        self.assertIn('Inspection incomplete', output)
        self.assertIn('Campaign matches: 1', output)
        self.assertIn('Result: INCOMPLETE', output)
        self.assertIn('(exit 2)', output)
        self.assertIn('Resolve the inspection errors', output)
        self.assertNotIn('Result: REVIEW NEEDED', output)

    def test_detail_output_is_opt_in_and_counts_are_preserved(self):
        for number in range(12):
            self.write(f'file-{number}.js', 'x' * 2100)
        output = self.scan(expected=1)
        detailed = self.scan('--details', expected=1)
        self.assertIn('Review signals: 12', output)
        self.assertIn('--details', output)
        self.assertGreater(detailed.count('line=1'), output.count('line=1'))

    def test_details_preserve_every_finding_and_advisory_beyond_twenty(self):
        for number in range(25):
            self.write(f'file-{number:02}.js', MARKER + '\n' + 'x' * 2100 + '\ncreateRequire')
        output = self.scan(expected=1)
        detailed = self.scan('--details', expected=1)
        for report in (output, detailed):
            self.assertIn('Campaign matches: 25; Review signals: 25', report)
            self.assertEqual(report.count('Result:'), 1)
        self.assertEqual(output.count('reason=known bootstrap signature'), 3)
        self.assertEqual(detailed.count('reason=known bootstrap signature'), 25)
        self.assertEqual(detailed.count('reason=line exceeds 2000'), 25)
        self.assertEqual(detailed.count('reason=createRequire'), 25)
        self.assertIn('file-24.js', detailed)
        self.assertNotIn('more location(s)', detailed)

    def test_details_preserve_every_error_beyond_fifty(self):
        for number in range(55):
            (self.root / f'broken-{number:02}').symlink_to(self.root / 'absent')
        output = self.scan(expected=2)
        detailed = self.scan('--details', expected=2)
        self.assertIn('Inspection errors: 55', detailed)
        self.assertEqual(output.count('reason=symlink could not be safely inspected'), 3)
        self.assertEqual(detailed.count('reason=symlink could not be safely inspected'), 55)
        self.assertIn('broken-54', detailed)

    def test_invalid_options_fail_before_scanning(self):
        output = self.scan('--unknown', expected=2)
        self.assertNotIn('Starting scan:', output)

    def test_missing_package_and_task_setting_are_detected(self):
        self.write('package.json', '{"dependencies":{"postcss-minify-selector":"1.0.0"}}')
        self.write('.vscode/settings.json', '{"task.allowAutomaticTasks":"on"}')
        output = self.scan(expected=1)
        self.assertIn('known malicious package name', output)
        self.assertIn('editor task can run', output)

    def test_binary_worktree_and_unreachable_blob_are_inspected(self):
        self.git('init', '-q')
        path = self.root / 'sample.bin'
        path.write_bytes(b'\0' + MARKER.encode() + b'\0')
        self.git('hash-object', '-w', str(path))
        output = self.scan(expected=1)
        self.assertIn('Campaign matches: 0; Review signals: 2', output)
        path.unlink()
        output = self.scan(expected=1)
        self.assertIn('Review signals: 1', output)
        self.assertIn('unreferenced-blob', output)

    def test_signing_check_is_opt_in_and_does_not_run_verifiers(self):
        self.git('init', '-q')
        self.write('readme.txt', 'ordinary source')
        self.git('add', '.')
        self.git('commit', '-qm', 'unsigned fixture')
        self.assertNotIn('Commit signature headers absent', self.scan(expected=0))
        output = self.scan('--check-signing', expected=1)
        self.assertIn('Signature headers checked: 1', output)
        self.assertIn('commit has no embedded signature header', output)
        self.assertIn('cryptographic validity is not verified', output)

    def test_workstation_checks_are_not_implicit(self):
        self.write('readme.txt', 'ordinary source')
        output = self.scan(expected=0)
        self.assertIn('Workstation checks: not requested', output)


if __name__ == '__main__':
    unittest.main()
