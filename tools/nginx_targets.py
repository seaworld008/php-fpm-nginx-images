#!/usr/bin/env python3
"""Turn `nginx -T` output into probe targets for upgrade and migration checks.

--probe  one "scheme<TAB>port<TAB>host" line per server_name and listen port of every HTTP server
         block, for tools/http_probe.sh. A port counts as TLS when any server block listening on it
         has the ssl parameter: nginx applies ssl per socket, so a plain "listen 443;" in another
         vhost still speaks TLS.
--fcgi   one "host<TAB>document_root<TAB>/index.php" line per server block that hands requests to
         PHP-FPM (fastcgi_pass in the block, in a nested location, or in an included file), for
         tools/fcgi_compare.py --targets.

Server blocks inside stream {} are ignored. Roots that are relative or contain variables are skipped.
"""
import argparse
import os
import re
import sys

SECTION = re.compile(r'# configuration file ([^\n:]+):\n(.*?)(?=\n# configuration file |\Z)', re.S)
TOKEN = re.compile(r'"[^"]*"|\'[^\']*\'|[{};]|[^\s{};]+')


def _blocks(text):
    """Yield (directives, in_stream) for every server block; nested blocks are flattened into it."""
    tokens = TOKEN.findall(re.sub(r'#[^\n]*', '', text))
    stack, cur = [], []
    for tok in tokens:
        if tok == '{':
            name = cur[0] if cur else ''
            in_stream = name == 'stream' or bool(stack and stack[-1]['stream'])
            stack.append({'name': name, 'd': [], 'stream': in_stream})
            cur = []
        elif tok == '}':
            if not stack:
                cur = []
                continue
            blk = stack.pop()
            if blk['name'] == 'server':
                yield blk['d'], blk['stream']
            elif stack:
                stack[-1]['d'].append(('__block__', [blk['name']]))
                stack[-1]['d'].extend(blk['d'])
            cur = []
        elif tok == ';':
            if cur and stack:
                stack[-1]['d'].append((cur[0], [a.strip('"\'') for a in cur[1:]]))
            cur = []
        else:
            cur.append(tok)


def server_blocks(text):
    """HTTP server blocks as lists of (directive, args)."""
    return [d for d, in_stream in _blocks(text) if not in_stream]


def _names(d):
    names = [n for k, v in d if k == 'server_name' for n in v]
    return [n for n in names if n not in ('_', '') and not n.startswith(('~', '*.')) and not n.endswith('.*')]


def _port(listen_args):
    addr = listen_args[0] if listen_args else '80'
    if addr.startswith('unix:'):
        return None
    port = addr.rsplit(':', 1)[-1] if ':' in addr else addr
    return port if port.isdigit() else None


def probe_targets(text):
    blocks = server_blocks(text)
    ssl_ports = set()
    for d in blocks:
        for k, v in d:
            if k == 'listen' and 'ssl' in v[1:] and _port(v):
                ssl_ports.add(_port(v))
    seen = []
    for d in blocks:
        listens = [v for k, v in d if k == 'listen'] or [['80']]
        hosts = _names(d) or ['127.0.0.1']
        for v in listens:
            port = _port(v)
            if not port:
                continue
            for host in hosts:
                t = ('https' if port in ssl_ports else 'http', port, host)
                if t not in seen:
                    seen.append(t)
    return seen


def fcgi_targets(text):
    php_files = {os.path.basename(name) for name, body in SECTION.findall(text)
                 if re.search(r'^\s*fastcgi_pass\s', body, re.M)}
    seen = []
    for d in server_blocks(text):
        uses_php = any(k == 'fastcgi_pass' or (k == 'include' and v and os.path.basename(v[0]) in php_files) for k, v in d)
        roots = [v[0] for k, v in d if k == 'root' and v and v[0].startswith('/') and '$' not in v[0]]
        names = _names(d)
        if uses_php and roots and names:
            t = (names[0], roots[0].rstrip('/') or '/', '/index.php')
            if t not in seen:
                seen.append(t)
    return seen


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument('--probe', action='store_true', help='scheme/port/host targets for tools/http_probe.sh')
    mode.add_argument('--fcgi', action='store_true', help='host/root/script targets for tools/fcgi_compare.py')
    ap.add_argument('dump', help='file with `nginx -T` output, or - for stdin')
    args = ap.parse_args(argv)
    text = sys.stdin.read() if args.dump == '-' else open(args.dump, encoding='utf-8', errors='replace').read()
    for t in (probe_targets(text) if args.probe else fcgi_targets(text)):
        print('\t'.join(t))
    return 0


if __name__ == '__main__':
    sys.exit(main())
