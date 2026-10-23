import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

try:
    from tools import ini_parity as ip
except ImportError:
    ip = None

HOST = {'ini': {'memory_limit': '128M', 'include_path': '.:/usr/share/pear:/usr/share/php', 'extension_dir': '/usr/lib64/php/modules',
                'session.save_path': '', 'date.timezone': 'PRC', 'sqlite3.defensive': ''},
        'ext': {'core': '7.2.34', 'redis': '5.3.7', 'mongodb': '1.16.2'}}
CTR = {'ini': {'memory_limit': '256M', 'include_path': '.:/usr/share/php', 'extension_dir': '/usr/lib/php/20170718',
               'session.save_path': '/var/lib/php/sessions', 'date.timezone': 'PRC', 'sqlite3.defensive': '1', 'msgpack.assoc': '1'},
       'ext': {'core': '7.2.34-66', 'redis': '5.3.7', 'mongodb': '1.16.2', 'sodium': '7.2.34-66'}}


class IniParityTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(ip, 'ini_parity implementation is not present')

    def test_diff_skips_ignored_and_equal_keys(self):
        diffs = {d.key: d for d in ip.diff(HOST, CTR, ignore={'extension_dir'})}
        self.assertEqual(set(diffs), {'memory_limit', 'include_path', 'session.save_path', 'sqlite3.defensive', 'msgpack.assoc'})
        self.assertEqual((diffs['memory_limit'].host, diffs['memory_limit'].container), ('128M', '256M'))

    def test_directives_missing_on_host_are_not_emitted(self):
        # msgpack 3.x adds msgpack.assoc; forcing the host's "nothing" (Off) would change unpacking to objects
        lines = ip.render(ip.diff(HOST, CTR, ignore={'extension_dir'}))
        self.assertNotIn('msgpack.assoc', '\n'.join(l for l in lines if not l.startswith(';')))
        self.assertTrue(any(l.startswith('; ') and 'msgpack.assoc' in l for l in lines))

    def test_values_are_quoted_safely(self):
        lines = ip.render(ip.diff(HOST, CTR, ignore={'extension_dir'}))
        self.assertIn('include_path = ".:/usr/share/pear:/usr/share/php"', lines)
        self.assertIn('session.save_path = ""', lines)
        self.assertIn('memory_limit = "128M"', lines)

    def test_extension_differences(self):
        only_host, only_ctr = ip.extension_diff(HOST, CTR)
        self.assertEqual((only_host, only_ctr), ([], ['sodium']))

    def test_main_reads_json_files(self):
        with tempfile.TemporaryDirectory() as d:
            h, c = Path(d, 'h.json'), Path(d, 'c.json')
            h.write_text(json.dumps(HOST)), c.write_text(json.dumps(CTR))
            with redirect_stdout(io.StringIO()) as out:
                rc = ip.main([str(h), str(c), '--ignore', 'extension_dir,sqlite3.defensive'])
        self.assertEqual(rc, 1)
        self.assertIn('memory_limit = "128M"', out.getvalue())
        self.assertNotIn('sqlite3.defensive =', out.getvalue())


if __name__ == '__main__':
    unittest.main()
