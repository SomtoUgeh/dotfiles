"""Run the documented Python/Ruby verifiers with deterministic transport fixtures."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import types
import unittest
from unittest.mock import Mock, patch

REFERENCE = Path(__file__).resolve().parents[1] / 'references/vanilla-html.md'


def snippet(language):
    return re.search(r'```' + language + r'\n(.*?)\n```', REFERENCE.read_text(), re.S).group(1)


class BackendExamplesTests(unittest.TestCase):
    def test_python_example(self):
        class RequestFailure(Exception):
            pass

        transport = types.ModuleType('requests')
        transport.RequestException = RequestFailure
        transport.post = Mock()
        scope = {}
        with patch.dict('sys.modules', {'requests': transport}), patch.dict(os.environ, {
            'TURNSTILE_SECRET': 'fixture-secret', 'TURNSTILE_HOSTNAMES': 'example.com',
        }, clear=True):
            exec(compile(snippet('python'), str(REFERENCE), 'exec'), scope)
            verify = scope['verify_turnstile']
            for token in [None, {}, '', 'x' * 2049]:
                self.assertFalse(verify(token))
            transport.post.assert_not_called()
            good = {'success': True, 'action': 'subscribe', 'hostname': 'example.com'}
            for body, expected in [(good, True), ({**good, 'success': 'true'}, False),
                                   ({**good, 'action': 'other'}, False),
                                   ({**good, 'hostname': 'other.example'}, False),
                                   ([], False), (None, False), ({'success': False}, False)]:
                transport.post.return_value = Mock(json=Mock(return_value=body))
                self.assertEqual(verify('fixture-token'), expected)
            transport.post.assert_called_with(
                'https://challenges.cloudflare.com/turnstile/v0/siteverify',
                data={'secret': 'fixture-secret', 'response': 'fixture-token'}, timeout=(5, 10),
            )
            transport.post.return_value = Mock(json=Mock(side_effect=ValueError('bad json')))
            self.assertFalse(verify('fixture-token'))
            transport.post.side_effect = RequestFailure('timeout')
            self.assertFalse(verify('fixture-token'))

    @unittest.skipUnless(shutil.which('ruby'), 'Ruby unavailable')
    def test_ruby_example(self):
        checks = r'''
ENV['TURNSTILE_SECRET'] = 'fixture-secret'
ENV['TURNSTILE_HOSTNAMES'] = 'example.com'
$mode = :ok
$calls = 0
class FixtureHTTP
  attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout
  def request(request)
    $calls += 1
    raise 'missing timeout' unless open_timeout == 5 && read_timeout == 10 && write_timeout == 10
    raise IOError, 'timeout' if $mode == :timeout
    response = $mode == :http_error ? Net::HTTPInternalServerError.new('1.1', '500', 'Error') : Net::HTTPOK.new('1.1', '200', 'OK')
    value = {'success' => true, 'action' => 'subscribe', 'hostname' => 'example.com'}
    value['success'] = 'true' if $mode == :truthy
    value['action'] = 'other' if $mode == :action
    value['hostname'] = 'other.example' if $mode == :hostname
    value = [] if $mode == :array
    response.body = $mode == :json ? 'bad json' : JSON.generate(value)
    response.instance_variable_set(:@read, true)
    response
  end
end
class << Net::HTTP
  def new(*args); FixtureHTTP.new; end
end
[nil, {}, '', 'x' * 2049].each { |token| raise 'accepted invalid token' if verify_turnstile(token) }
raise 'invalid input requested HTTP' unless $calls == 0
raise 'valid response rejected' unless verify_turnstile('fixture-token')
[:timeout, :http_error, :truthy, :action, :hostname, :array, :json].each do |mode|
  $mode = mode
  raise "accepted #{mode}" if verify_turnstile('fixture-token')
end
puts 'Ruby verification scenarios passed'
'''
        result = subprocess.run(['ruby', '-e', snippet('ruby') + '\n' + checks],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('scenarios passed', result.stdout)


if __name__ == '__main__':
    unittest.main()
