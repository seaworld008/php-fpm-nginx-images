#!/usr/bin/env python3
"""Compare effective PHP settings of the current runtime and its replacement; print a parity ini.

Inputs are JSON dumps written by variants/php72-host-compat/kit/ini_dump.php, taken through the
real SAPI (FastCGI for FPM, php for CLI): {"ini": {directive: value}, "ext": {name: version}}.
For every directive whose value differs, the host value is printed as `key = "value"`, ready to be
mounted as an extra conf.d file. Directives that exist only in the replacement (for example
msgpack.assoc, added in msgpack 3.0) are printed as comments and never forced: the host has no
value for them, and writing "nothing" can change behaviour.
Exit code: 0 when nothing differs after --ignore, 1 otherwise.
"""
import argparse
import json
import sys
from collections import namedtuple

Diff = namedtuple('Diff', 'key host container')


def diff(host, ctr, ignore=()):
    hi, ci = host.get('ini', {}), ctr.get('ini', {})
    return [Diff(k, hi.get(k), ci.get(k)) for k in sorted(set(hi) | set(ci))
            if k not in ignore and hi.get(k) != ci.get(k)]


def extension_diff(host, ctr):
    he, ce = set(host.get('ext', {})), set(ctr.get('ext', {}))
    return sorted(he - ce), sorted(ce - he)


def _quote(value):
    return '"%s"' % str(value).replace('\\', '\\\\').replace('"', '\\"')


def render(diffs):
    lines = []
    for d in diffs:
        if d.host is None:
            lines.append('; %s：只有新环境有这个指令（当前值 %s），不写入' % (d.key, d.container))
        else:
            if d.container is None:
                lines.append('; %s：新环境没有这个指令，写入后会被忽略' % d.key)
            lines.append('%s = %s' % (d.key, _quote(d.host)))
    return lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('host_json', help='dump from the current runtime')
    ap.add_argument('container_json', help='dump from the replacement')
    ap.add_argument('--ignore', default='', help='comma separated directives that are expected to differ')
    args = ap.parse_args(argv)
    with open(args.host_json, encoding='utf-8') as fh, open(args.container_json, encoding='utf-8') as fc:
        host, ctr = json.load(fh), json.load(fc)
    ignore = {k.strip() for k in args.ignore.split(',') if k.strip()}
    only_host, only_ctr = extension_diff(host, ctr)
    print('; 扩展：只有当前环境有 %s；只有新环境有 %s' % (only_host, only_ctr))
    diffs = diff(host, ctr, ignore)
    for line in render(diffs):
        print(line)
    return 1 if diffs or only_host else 0


if __name__ == '__main__':
    sys.exit(main())
