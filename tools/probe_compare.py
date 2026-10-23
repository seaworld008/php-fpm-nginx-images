#!/usr/bin/env python3
"""Compare two tools/http_probe.sh result files taken before and after a change.

A row matches when status code, content type and redirect target are identical and the body size
differs by no more than max(300 bytes, 5%). Rows present before but missing after are reported too.
Dynamic pages (random SSO tokens, timestamps) can still differ: probe the same target twice against
the old runtime to tell such noise from a real change.
Exit code: 0 when every row matches, 1 otherwise.
"""
import argparse
import sys


def load(fh):
    rows = {}
    for line in fh:
        p = line.rstrip('\n').split('\t')
        if len(p) < 5:
            continue
        p += [''] * (8 - len(p))
        rows[tuple(p[:4])] = (p[4], int(p[5] or 0), p[6], p[7])
    return rows


def differences(before, after, ratio=0.05, floor=300):
    out = []
    for key in sorted(before):
        b, a = before[key], after.get(key)
        if a is None:
            out.append(('missing', key, b, None))
        elif (b[0], b[2], b[3]) != (a[0], a[2], a[3]) or abs(b[1] - a[1]) > max(floor, b[1] * ratio):
            out.append(('changed', key, b, a))
    return out


def _fmt(r):
    return '-' if r is None else '%s %sB %s %s' % (r[0], r[1], r[2], r[3][:60])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('before')
    ap.add_argument('after')
    args = ap.parse_args(argv)
    with open(args.before, encoding='utf-8', errors='replace') as fb, open(args.after, encoding='utf-8', errors='replace') as fa:
        before, after = load(fb), load(fa)
    diffs = differences(before, after)
    for kind, key, b, a in diffs:
        print('%s %s://%s:%s%s  前[%s]  后[%s]' % ('缺失' if kind == 'missing' else '不同', key[0], key[2], key[1], key[3], _fmt(b), _fmt(a)))
    print('共 %d 条，不同 %d 条' % (len(before), len(diffs)))
    return 1 if diffs else 0


if __name__ == '__main__':
    sys.exit(main())
