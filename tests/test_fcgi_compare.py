import socket
import struct
import threading
import unittest

try:
    from tools import fcgi_compare as fc
except ImportError:
    fc = None


def record(rtype, content, request_id=1):
    pad = (8 - len(content) % 8) % 8
    return struct.pack('!BBHHBx', 1, rtype, request_id, len(content), pad) + content + b'\0' * pad


class FakeFpm(threading.Thread):
    """Accepts one connection, records the request bytes, answers with canned records."""

    def __init__(self, reply):
        super().__init__(daemon=True)
        self.reply = reply
        self.received = b''
        self.sock = socket.socket()
        self.sock.bind(('127.0.0.1', 0))
        self.sock.listen(1)
        self.port = self.sock.getsockname()[1]

    def run(self):
        conn, _ = self.sock.accept()
        conn.settimeout(5)
        try:
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                self.received += chunk
                if record(5, b'') in self.received:
                    break
            conn.sendall(self.reply)
        finally:
            conn.close()
            self.sock.close()


class FcgiCompareTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(fc, 'fcgi_compare implementation is not present')

    def test_length_encoding_short_and_long(self):
        self.assertEqual(fc.encode_length(5), b'\x05')
        self.assertEqual(fc.encode_length(127), b'\x7f')
        self.assertEqual(fc.encode_length(128), struct.pack('!I', 128 | 0x80000000))

    def test_params_encoding_roundtrip_shape(self):
        data = fc.encode_params({'A': 'bc', 'LONG': 'x' * 200})
        self.assertTrue(data.startswith(b'\x01\x02Abc'))
        self.assertIn(b'\x04' + struct.pack('!I', 200 | 0x80000000) + b'LONG', data)

    def test_request_contains_begin_params_and_stdin_terminators(self):
        req = fc.build_request({'SCRIPT_FILENAME': '/app/index.php'})
        self.assertEqual(req[:8], struct.pack('!BBHHBx', 1, 1, 1, 8, 0))
        self.assertIn(record(4, b''), req)
        self.assertTrue(req.endswith(record(5, b'')))

    def test_split_records_collects_stdout_and_stderr(self):
        data = record(6, b'Status: 302 Found\r\n') + record(7, b'oops') + record(6, b'Location: /login\r\n\r\nbody') + record(3, b'\0' * 8)
        out, err = fc.split_records(data)
        self.assertEqual(out, b'Status: 302 Found\r\nLocation: /login\r\n\r\nbody')
        self.assertEqual(err, b'oops')

    def test_parse_response_defaults_and_errors(self):
        r = fc.parse_response(b'Content-Type: text/html\r\n\r\n<b>Fatal error</b>: x', b'')
        self.assertEqual((r.status, r.location, r.length, r.php_error), ('200', '', 21, True))
        r = fc.parse_response(b'Status: 404 Not Found\r\n\r\nnope', b'')
        self.assertEqual((r.status, r.php_error), ('404', False))

    def test_same_response_tolerates_small_dynamic_differences(self):
        a = fc.Response('200', '', 10000, False)
        self.assertTrue(fc.same_response(a, fc.Response('200', '', 10300, False)))
        self.assertFalse(fc.same_response(a, fc.Response('200', '', 11000, False)))
        self.assertFalse(fc.same_response(a, fc.Response('500', '', 10000, False)))
        self.assertFalse(fc.same_response(a, fc.Response('200', '', 10000, True)))
        self.assertTrue(fc.same_response(fc.Response('200', '', 5, False), fc.Response('200', '', 150, False)))

    def test_request_against_fake_server(self):
        reply = record(6, b'Status: 302 Found\r\nLocation: /admin/login\r\n\r\n') + record(3, b'\0' * 8)
        srv = FakeFpm(reply)
        srv.start()
        resp = fc.fcgi_request('127.0.0.1', srv.port, {'REQUEST_METHOD': 'GET', 'SCRIPT_FILENAME': '/app/index.php'})
        srv.join(5)
        self.assertEqual((resp.status, resp.location), ('302', '/admin/login'))
        self.assertIn(b'SCRIPT_FILENAME/app/index.php', srv.received)

    def test_targets_from_tsv_and_params(self):
        targets = fc.parse_targets(['# comment', 'example.com\t/srv/app/public\t/index.php', 'b.com\t/srv/b\t/admin.php\ts=/x'])
        self.assertEqual(len(targets), 2)
        p = fc.request_params(targets[1])
        self.assertEqual(p['SCRIPT_FILENAME'], '/srv/b/admin.php')
        self.assertEqual(p['QUERY_STRING'], 's=/x')
        self.assertEqual(p['REQUEST_URI'], '/admin.php?s=/x')
        self.assertEqual(p['HTTP_HOST'], 'b.com')
        self.assertEqual(p['REQUEST_METHOD'], 'GET')


if __name__ == '__main__':
    unittest.main()
