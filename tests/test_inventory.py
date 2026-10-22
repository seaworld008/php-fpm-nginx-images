import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

try:
    from tools import inventory
except ImportError:
    inventory = None


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(inventory, 'inventory implementation is not present')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def fake(self, name, payload=None, code=0, stderr=''):
        path = self.root / name
        text = json.dumps(payload) if payload is not None else 'PHP 7.2.34 (fpm-fcgi)'
        path.write_text('#!' + sys.executable + '\nimport sys\n'
                        + 'print(' + repr(text) + ')\n'
                        + 'sys.stderr.write(' + repr(stderr) + ')\n'
                        + 'sys.exit(' + str(code) + ')\n')
        path.chmod(0o700)
        return str(path)

    def payload(self):
        return {'version': '7.2.34-vendor', 'sapi': 'cli',
                'extensions': {'json': '1.6.0'}, 'loaded_ini': '/local/php.ini'}

    def test_success_does_not_claim_patched(self):
        php = self.fake('php with spaces', self.payload())
        report = inventory.collect(php, None)
        self.assertEqual(report['security_status'], 'UNVERIFIED')
        self.assertEqual(report['cli']['status'], 'COLLECTED')
        self.assertEqual(report['cli']['metadata']['version'], '7.2.34-vendor')
        self.assertEqual(report['fpm']['status'], 'NOT_REQUESTED')
        self.assertNotIn('hostname', report)
        self.assertNotIn('environment', report)

    def test_missing_binary_is_visible(self):
        report = inventory.collect(str(self.root / 'missing'), None)
        self.assertEqual(report['cli']['status'], 'NOT_FOUND')
        self.assertEqual(report['security_status'], 'UNVERIFIED')

    def test_startup_warnings_preserved(self):
        php = self.fake('php', self.payload(), stderr="Module 'mongodb' already loaded\n")
        report = inventory.collect(php, None)
        self.assertEqual(report['cli']['status'], 'COLLECTED')
        self.assertIn('already loaded', report['cli']['stderr'])

    def test_nonzero_return_not_success(self):
        php = self.fake('php', self.payload(), code=1)
        self.assertEqual(inventory.collect(php, None)['cli']['status'], 'ERROR')

    def test_invalid_json_not_success(self):
        php = self.fake('php')
        self.assertEqual(inventory.collect(php, None)['cli']['status'], 'ERROR')

    def test_wrong_json_shape_not_success(self):
        php = self.fake('php', ['not', 'metadata'])
        self.assertEqual(inventory.collect(php, None)['cli']['status'], 'ERROR')

    def test_fpm_is_explicit_version_only(self):
        php = self.fake('php', self.payload())
        fpm = self.fake('fpm')
        report = inventory.collect(php, fpm)
        self.assertEqual(report['fpm']['status'], 'COLLECTED_VERSION_ONLY')
        self.assertIn('7.2.34', report['fpm']['stdout'])

    def test_command_timeout_is_bounded(self):
        result = inventory.run_command([sys.executable, '-c', 'import time; time.sleep(3)'], 0.05)
        self.assertFalse(result['ok'])
        self.assertEqual(result['error'], 'TIMEOUT')

    def test_metacharacters_are_not_shell(self):
        path = self.fake('php;literal', self.payload())
        self.assertEqual(inventory.collect(path, None)['cli']['status'], 'COLLECTED')

    def test_os_release_is_allowlisted(self):
        path = self.root / 'os-release'
        path.write_text('ID=debian\nVERSION_ID="12"\nPRETTY_NAME="Debian GNU/Linux"\nSECRET=do-not-report\n')
        result = inventory.read_os_release(path)
        self.assertEqual(result['ID'], 'debian')
        self.assertEqual(result['VERSION_ID'], '12')
        self.assertNotIn('SECRET', result)

    def test_missing_os_release_does_not_crash(self):
        self.assertEqual(inventory.read_os_release(self.root / 'absent'), {})

    def test_cli_exit_failure_is_json(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = inventory.main(['--php', str(self.root / 'absent')])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(output.getvalue())['cli']['status'], 'NOT_FOUND')

    def test_requested_missing_fpm_is_failure(self):
        php = self.fake('php', self.payload())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = inventory.main(['--php', php, '--fpm', str(self.root / 'absent')])
        self.assertEqual(code, 2)

    def test_out_of_range_timeout_rejected(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                inventory.main(['--timeout', '0'])


if __name__ == '__main__':
    unittest.main()
