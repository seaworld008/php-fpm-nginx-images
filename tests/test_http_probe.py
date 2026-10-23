import shutil
import socket
import subprocess
import tempfile
import threading
import unittest
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / 'tools' / 'http_probe.sh'


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


@unittest.skipUnless(shutil.which('curl') and shutil.which('bash'), 'curl and bash are required')
class HttpProbeTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.exists(), 'tools/http_probe.sh is not present')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        Path(self.tmp.name, 'index.html').write_text('hello')
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=self.tmp.name))
        self.port = self.server.server_address[1]
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    def test_probe_records_status_for_root_and_missing_path(self):
        out = subprocess.run(['bash', str(SCRIPT)], input='http\t%d\tprobe.test\n' % self.port,
                             capture_output=True, text=True, timeout=60, check=True).stdout
        rows = [line.split('\t') for line in out.splitlines()]
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0][:5], ['http', str(self.port), 'probe.test', '/', '200'])
        self.assertEqual(rows[0][5], '5')
        self.assertEqual(rows[1][3:5], ['/__nginx_upgrade_check__.html', '404'])

    def test_unreachable_target_is_reported_as_000(self):
        s = socket.socket()
        s.bind(('127.0.0.1', 0))
        free = s.getsockname()[1]
        s.close()
        out = subprocess.run(['bash', str(SCRIPT)], input='http\t%d\tprobe.test\n' % free,
                             capture_output=True, text=True, timeout=60, check=True).stdout
        self.assertEqual(out.splitlines()[0].split('\t')[4], '000')


if __name__ == '__main__':
    unittest.main()
