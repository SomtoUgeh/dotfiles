"""Offline tests for persistence, creation, and metadata validation helpers."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

BUNDLE = Path(__file__).resolve().parents[1]
MOCK = '''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
args=sys.argv[1:]
data=json.loads(os.environ['FIXTURE_RESPONSE'])
token=data['token']
with Path(os.environ['FIXTURE_CALLS']).open('a') as calls:
 calls.write(json.dumps(args)+'\\n')
assert token not in str(args)
assert 'CLOUDFLARE_API_TOKEN' not in os.environ
assert '--connect-timeout' in args and '--max-time' in args
incoming=sys.stdin.read()
if '--config' in args:
 assert args[args.index('--config')+1]=='-'
 assert incoming == f'header = "Authorization: Bearer {token}"\\n'
if '--write-out' in args:
 print(json.dumps(data['body']) if not isinstance(data['body'],str) else data['body'])
 print(data['http'])
else:
 if '--fail' in args and not 200 <= int(data['http']) < 300: sys.exit(22)
 body=data['siteverify'] if 'siteverify' in str(args) else data['body']
 print(json.dumps(body))
'''

class HelpersTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'; self.bin.mkdir()
        (self.bin / 'python3').symlink_to(sys.executable)
        jq = shutil.which('jq')
        if not jq: self.skipTest('jq unavailable')
        (self.bin / 'jq').symlink_to(jq)
        curl = self.bin / 'curl'; curl.write_text(MOCK); curl.chmod(0o755)
        self.env = {'PATH': str(self.bin), 'CLOUDFLARE_API_TOKEN': 'fixture-api-token'}
        self.calls_path = self.root / 'curl-calls.jsonl'
        self.env['FIXTURE_CALLS'] = str(self.calls_path)

    def run_helper(self, script, *args, body=None, http='200', secret='fixture-secret', siteverify=None):
        self.env['FIXTURE_RESPONSE'] = json.dumps({'body': body, 'http': http, 'siteverify': siteverify,
                                                 'token': self.env['CLOUDFLARE_API_TOKEN']})
        return subprocess.run(['/bin/bash', str(BUNDLE / 'scripts' / script), *args],
                              cwd=self.root, env=self.env, input=secret, text=True,
                              capture_output=True, timeout=10)

    def test_creation_requires_http_and_application_success(self):
        valid = {'success': True, 'result': {'sitekey': 'fixture-sitekey', 'secret': 'fixture-secret'}}
        for code, body, succeeds in [('200',valid,True),('201',valid,True),('500',valid,False),
                                    ('200',{'success': False},False),('200',{},False),('200','not json',False),
                                    ('200',{'success':True,'result':{'sitekey':'x'}},False)]:
            with self.subTest(code=code,body=body):
                result=self.run_helper('widget-create.sh','--account-id','account','--name','fixture','--domains','example.com',body=body,http=code)
                self.assertEqual(result.returncode == 0,succeeds)
                self.assertEqual(json.loads(result.stdout)['status'],'ok' if succeeds else 'error')
                self.assertNotIn('fixture-api-token',result.stdout+result.stderr)
                if not succeeds: self.assertNotIn('fixture-secret',result.stdout+result.stderr)

    def test_validation_checks_metadata_secret_and_dummy_result(self):
        widget={'success':True,'result':{'sitekey':'sitekey','secret':'fixture-secret','domains':['example.com'],'clearance_level':'no_clearance'}}
        dummy={'success':False,'error-codes':['invalid-input-response']}
        cases=[(widget,dummy,'fixture-secret',True),(widget,dummy,'wrong-secret',False),
               (widget,{'success':True},'fixture-secret',False),
               (widget,{'success':False,'error-codes':['invalid-input-response','invalid-input-secret']},'fixture-secret',False),
               ({'success':False},dummy,'fixture-secret',False)]
        for body, verify, secret, succeeds in cases:
            with self.subTest(body=body,verify=verify,secret=secret):
                result=self.run_helper('validate.sh','--account-id','account','--sitekey','sitekey','--expected-domains','["example.com"]',body=body,siteverify=verify,secret=secret)
                self.assertEqual(result.returncode == 0,succeeds,result.stderr)
                self.assertNotIn('fixture-secret',result.stdout+result.stderr)
                self.assertNotIn('fixture-api-token',result.stdout+result.stderr)

    def test_oauth_jwt_reaches_creation_and_validation_without_exposure(self):
        token = 'eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJmaXh0dXJlIn0.signature_-01'
        self.env['CLOUDFLARE_API_TOKEN'] = token
        widget = {'success': True, 'result': {'sitekey': 'sitekey', 'secret': 'fixture-secret',
                  'domains': ['example.com'], 'clearance_level': 'no_clearance'}}
        created = self.run_helper('widget-create.sh', '--account-id', 'account', '--name', 'fixture',
                                  '--domains', 'example.com', body=widget)
        validated = self.run_helper('validate.sh', '--account-id', 'account', '--sitekey', 'sitekey',
                                    '--expected-domains', '["example.com"]', body=widget,
                                    siteverify={'success': False, 'error-codes': ['invalid-input-response']})
        for result in (created, validated):
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['status'], 'ok')
            self.assertNotIn(token, result.stdout + result.stderr)
        self.assertEqual(len(self.calls_path.read_text().splitlines()), 3)

    def test_unsafe_token_never_reaches_creation_or_validation_curl(self):
        for token in ('bad"token', 'bad\\token', 'bad\ntoken', 'bad\rtoken', 'bad\ttoken',
                      'bad token', 'token"\nurl = "https://attacker.invalid',
                      'token\\noutput = "/tmp/injected"'):
            self.env['CLOUDFLARE_API_TOKEN'] = token
            for script, args in (
                ('widget-create.sh', ['--account-id', 'account', '--name', 'fixture', '--domains', 'example.com']),
                ('validate.sh', ['--account-id', 'account', '--sitekey', 'sitekey', '--expected-domains', '["example.com"]']),
            ):
                with self.subTest(token=token, script=script):
                    result = self.run_helper(script, *args)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('invalid format', result.stderr)
                    self.assertNotIn(token, result.stdout + result.stderr)
                    self.assertFalse(self.calls_path.exists())

    def test_persistence_copies_local_bundle_and_preserves_existing_target(self):
        target=self.root/'.agents/skills/turnstile-spin'
        result=self.run_helper('persist-skill.sh','--path',str(target/'SKILL.md'))
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)['status'],'ok')
        for source in BUNDLE.rglob('*'):
            if source.is_file() and '__pycache__' not in source.parts and source.suffix!='.pyc':
                self.assertEqual(source.read_bytes(),(target/source.relative_to(BUNDLE)).read_bytes())
        result=self.run_helper('persist-skill.sh','--path',str(target/'SKILL.md'))
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((target/'SKILL.md').read_bytes(),(BUNDLE/'SKILL.md').read_bytes())

    def test_persistence_rejects_escaping_target(self):
        for path in (str(self.root.parent/'outside-skill/SKILL.md'),str(self.root/'SKILL.md'),str(self.root/'x/not-skill.txt')):
            result=self.run_helper('persist-skill.sh','--path',path)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(json.loads(result.stdout)['status'],'error')

    def test_copy_failure_never_reports_success(self):
        # Run a copied helper with a disposable invalid source member.
        source=self.root/'source'; (source/'scripts').mkdir(parents=True)
        shutil.copy2(BUNDLE/'scripts/persist-skill.sh',source/'scripts/persist-skill.sh')
        (source/'SKILL.md').write_text('fixture')
        os.mkfifo(source/'unreadable-resource')
        target=self.root/'target'
        result=subprocess.run(['/bin/bash',str(source/'scripts/persist-skill.sh'),'--path',str(target/'SKILL.md')],cwd=self.root,env=self.env,text=True,capture_output=True,timeout=10)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(json.loads(result.stdout)['status'],'error')
        self.assertFalse(target.exists())
        self.assertFalse(list(self.root.glob('.turnstile-persist-*')))

if __name__ == '__main__':
    unittest.main()
