#!/usr/bin/env python3
"""Compare two PHP-FPM endpoints by sending identical read-only FastCGI GET requests.

Used to validate a replacement PHP runtime side by side with the one serving
production, before switching traffic. Only GET requests are sent; no request
body, no cookies, so application state is not modified beyond what a normal
anonymous page view does (logs, caches).

Targets come from a TSV file (host, document_root, script[, query]) or from
--scan, which emits one target per <dir>/*/public/index.php found on the host.
Exit code: 0 when every target matches, 1 when any differs, 2 on usage errors.
"""
import argparse
import glob
import os
import re
import socket
import struct
import sys
from collections import namedtuple

FCGI_VERSION = 1
BEGIN_REQUEST, END_REQUEST, PARAMS, STDIN, STDOUT, STDERR = 1, 3, 4, 5, 6, 7
RESPONDER = 1
PHP_ERROR = re.compile(rb'Fatal error|Parse error|Uncaught |Warning: |Call to undefined')

Response = namedtuple('Response', 'status location length php_error')
Target = namedtuple('Target', 'host root script query')


def encode_length(n):
    return struct.pack('!B', n) if n < 128 else struct.pack('!I', n | 0x80000000)


def encode_params(params):
    out = b''
    for key, value in params.items():
        k, v = str(key).encode(), str(value).encode()
        out += encode_length(len(k)) + encode_length(len(v)) + k + v
    return out


def _record(rtype, content, request_id=1):
    if not content:
        return struct.pack('!BBHHBx', FCGI_VERSION, rtype, request_id, 0, 0)
    out = b''
    for i in range(0, len(content), 65535):
        chunk = content[i:i + 65535]
        pad = (8 - len(chunk) % 8) % 8
        out += struct.pack('!BBHHBx', FCGI_VERSION, rtype, request_id, len(chunk), pad) + chunk + b'\0' * pad
    return out


def build_request(params):
    begin = struct.pack('!HB5x', RESPONDER, 0)
    return (_record(BEGIN_REQUEST, begin) + _record(PARAMS, encode_params(params))
            + _record(PARAMS, b'') + _record(STDIN, b''))


def split_records(data):
    out, err, pos = b'', b'', 0
    while pos + 8 <= len(data):
        _, rtype, _, clen, plen = struct.unpack('!BBHHBx', data[pos:pos + 8])
        content = data[pos + 8:pos + 8 + clen]
        pos += 8 + clen + plen
        if rtype == STDOUT:
            out += content
        elif rtype == STDERR:
            err += content
        elif rtype == END_REQUEST:
            break
    return out, err


def parse_response(stdout, stderr):
    head, _, body = stdout.partition(b'\r\n\r\n')
    text = head.decode('latin1')
    status = re.search(r'^Status:\s*(\d{3})', text, re.M)
    location = re.search(r'^Location:\s*(\S+)', text, re.M)
    return Response(status.group(1) if status else '200', location.group(1) if location else '',
                    len(body), bool(PHP_ERROR.search(body + stderr)))


def fcgi_request(host, port, params, timeout=30):
    with socket.create_connection((host, int(port)), timeout=timeout) as sock:
        sock.sendall(build_request(params))
        data = b''
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            data += chunk
            if _has_end_request(data):
                break
    return parse_response(*split_records(data))


def _has_end_request(data):
    pos = 0
    while pos + 8 <= len(data):
        _, rtype, _, clen, plen = struct.unpack('!BBHHBx', data[pos:pos + 8])
        if rtype == END_REQUEST and pos + 8 + clen <= len(data):
            return True
        pos += 8 + clen + plen
    return False


def same_response(a, b, ratio=0.05, floor=200):
    if (a.status, a.location, a.php_error) != (b.status, b.location, b.php_error):
        return False
    return abs(a.length - b.length) <= max(floor, a.length * ratio)


def parse_targets(lines):
    targets = []
    for line in lines:
        line = line.rstrip('\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            raise ValueError('target needs host, document_root, script: %r' % line)
        targets.append(Target(parts[0], parts[1].rstrip('/'), parts[2], parts[3] if len(parts) > 3 else ''))
    return targets


def scan_targets(host_root, container_root, host_header='localhost'):
    found = sorted(glob.glob(os.path.join(host_root, '*', 'public', 'index.php')))
    return [Target(host_header, os.path.dirname(f).replace(host_root.rstrip('/'), container_root.rstrip('/'), 1),
                   '/index.php', '') for f in found]


def request_params(t, https=True):
    uri = t.script + ('?' + t.query if t.query else '')
    return {
        'GATEWAY_INTERFACE': 'CGI/1.1', 'REQUEST_METHOD': 'GET', 'QUERY_STRING': t.query,
        'REQUEST_URI': uri, 'DOCUMENT_URI': t.script, 'SCRIPT_NAME': t.script,
        'SCRIPT_FILENAME': t.root + t.script, 'DOCUMENT_ROOT': t.root, 'SERVER_PROTOCOL': 'HTTP/1.1',
        'REQUEST_SCHEME': 'https' if https else 'http', 'HTTPS': 'on' if https else '',
        'SERVER_NAME': t.host, 'SERVER_PORT': '443' if https else '80', 'HTTP_HOST': t.host,
        'REMOTE_ADDR': '127.0.0.1', 'REMOTE_PORT': '50000', 'HTTP_USER_AGENT': 'fcgi-compare/1.0',
    }


def _endpoint(value):
    host, _, port = value.rpartition(':')
    if not host or not port.isdigit():
        raise argparse.ArgumentTypeError('expected HOST:PORT, got %r' % value)
    return host, int(port)


def _describe(r):
    if isinstance(r, Exception):
        return 'ERR %s' % type(r).__name__
    extra = (' ->' + r.location[:40]) if r.location else ''
    return '%s %7dB%s%s' % (r.status, r.length, ' PHP错误' if r.php_error else '', extra)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--old', type=_endpoint, required=True, help='current FPM HOST:PORT')
    ap.add_argument('--new', type=_endpoint, required=True, help='candidate FPM HOST:PORT')
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument('--targets', help='TSV: host<TAB>document_root<TAB>script[<TAB>query]')
    src.add_argument('--scan', nargs=2, metavar=('HOST_ROOT', 'CONTAINER_ROOT'),
                     help='emit <HOST_ROOT>/*/public/index.php, mapped to CONTAINER_ROOT')
    ap.add_argument('--http', action='store_true', help='send HTTPS=off (default mimics a TLS-terminating gateway)')
    args = ap.parse_args(argv)
    if args.targets:
        with open(args.targets, encoding='utf-8') as fh:
            targets = parse_targets(fh)
    else:
        targets = scan_targets(*args.scan)
    if not targets:
        print('no targets', file=sys.stderr)
        return 2
    differ = 0
    for t in targets:
        params = request_params(t, https=not args.http)
        results = []
        for host, port in (args.old, args.new):
            try:
                results.append(fcgi_request(host, port, params))
            except (OSError, ValueError) as exc:
                results.append(exc)
        ok = all(isinstance(r, Response) for r in results) and same_response(*results)
        differ += not ok
        print('%s %-34s %-30s old[%s]  new[%s]' % ('  ' if ok else 'X ', t.host[:34], (t.root.rsplit('/', 2)[-2] + t.script)[:30],
                                                   _describe(results[0]), _describe(results[1])))
    print('targets: %d, different: %d' % (len(targets), differ))
    return 1 if differ else 0


if __name__ == '__main__':
    sys.exit(main())
