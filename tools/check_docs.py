#!/usr/bin/env python3
"""Offline local-file links, code-fence and JSON checks, not a security audit.

Does not fetch external links or validate Markdown fragments/anchor targets.
Supports ordinary inline Markdown links used in this repository.
"""
from pathlib import Path
import json
import re
import sys
from typing import List
from urllib.parse import unquote, urlsplit

LINK = re.compile(r'!?\[[^\]\n]*\]\(([^)\s]+)\)')
FENCE = re.compile(r'^\s{0,3}(`{3,}|~{3,})(.*)$')
SKIP_PARTS = {'.git', '__pycache__', '.venv', '.local', 'artifacts', 'private-evidence'}


def validate(root: Path) -> List[str]:
    root = root.resolve()
    errors = []
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if set(relative.parts) & SKIP_PARTS or not path.is_file():
            continue
        if path.suffix not in ('.md', '.json'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (UnicodeError, OSError) as exc:
            errors.append('{}: {}'.format(relative, exc))
            continue
        if path.suffix == '.json':
            try:
                json.loads(text)
            except ValueError as exc:
                errors.append('{}: invalid JSON: {}'.format(relative, exc))
            continue
        fence = None
        for number, line in enumerate(text.splitlines(), 1):
            match = FENCE.match(line)
            if match:
                delimiter, rest = match.groups()
                if fence is None:
                    fence = delimiter
                    continue
                if delimiter[0] == fence[0] and len(delimiter) >= len(fence) and not rest.strip():
                    fence = None
                    continue
            if fence is not None:
                continue
            for href in LINK.findall(line):
                parsed = urlsplit(href.strip('<>'))
                if parsed.scheme or parsed.netloc or not parsed.path:
                    continue
                target = (path.parent / unquote(parsed.path)).resolve()
                try:
                    target.relative_to(root)
                except ValueError:
                    errors.append('{}:{}: link escapes repository: {}'.format(relative, number, href))
                    continue
                if not target.exists():
                    errors.append('{}:{}: missing local link: {}'.format(relative, number, href))
        if fence is not None:
            errors.append('{}: unclosed code fence'.format(relative))
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate(root)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('PASS: local Markdown file links/fences and JSON syntax; not runtime/security validation.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
