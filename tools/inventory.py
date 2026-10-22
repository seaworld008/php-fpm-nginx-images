#!/usr/bin/env python3
"""Collect minimal local PHP metadata; never decide whether a CVE is fixed.

Only invoke trusted binaries. PHP extensions may run initialization code.
Output is local evidence and can contain paths/startup diagnostics: redact it.
Python 3.8+, standard library only. No install, config edit or service restart.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
from typing import Any, Dict, List, Optional, Sequence

PHP_METADATA = r'''
$extensions = array();
foreach (get_loaded_extensions() as $name) {
    $extensions[$name] = phpversion($name);
}
ksort($extensions);
echo json_encode(array(
    "version" => PHP_VERSION,
    "version_id" => PHP_VERSION_ID,
    "sapi" => PHP_SAPI,
    "zts" => PHP_ZTS,
    "loaded_ini" => php_ini_loaded_file(),
    "scanned_ini" => php_ini_scanned_files(),
    "extension_dir" => ini_get("extension_dir"),
    "extensions" => $extensions,
    "zend_extensions" => get_loaded_extensions(true)
), JSON_UNESCAPED_SLASHES);
'''


def run_command(argv: Sequence[str], timeout: float = 10) -> Dict[str, Any]:
    """Run a bounded argument-vector command, never through a shell."""
    try:
        result = subprocess.run(list(argv), stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, encoding='utf-8', errors='replace',
                                timeout=timeout, check=False, shell=False)
        return {'ok': result.returncode == 0, 'returncode': result.returncode,
                'stdout': result.stdout, 'stderr': result.stderr, 'error': None}
    except subprocess.TimeoutExpired:
        return {'ok': False, 'returncode': None, 'stdout': '', 'stderr': '',
                'error': 'TIMEOUT'}
    except OSError as exc:
        return {'ok': False, 'returncode': None, 'stdout': '', 'stderr': str(exc),
                'error': 'EXECUTION_ERROR'}


def read_os_release(path: Path = Path('/etc/os-release')) -> Dict[str, str]:
    """Parse only public OS labels; never source a shell file."""
    selected = {}
    try:
        for line in path.read_text(encoding='utf-8').splitlines():
            key, sep, value = line.partition('=')
            if sep and key in ('ID', 'VERSION_ID', 'PRETTY_NAME'):
                try:
                    selected[key] = ' '.join(shlex.split(value, comments=True))
                except ValueError:
                    continue
    except OSError:
        pass
    return selected


def collect(php: str, fpm: Optional[str], timeout: float = 10) -> Dict[str, Any]:
    report = {
        'schema_version': 1,
        'collected_at_utc': datetime.now(timezone.utc).isoformat(),
        'security_status': 'UNVERIFIED',
        'os': read_os_release(),
        'architecture': platform.machine(),
        'notes': [
            'CLI metadata is not an actual FPM request or patch verification.',
            'FPM is queried only when explicitly supplied; version output only.',
            'Review local paths and startup diagnostics before sharing.'
        ],
        'cli': {'status': 'NOT_FOUND'},
        'fpm': {'status': 'NOT_REQUESTED'}
    }
    binary = shutil.which(php)
    if binary:
        result = run_command([binary, '-d', 'auto_prepend_file=', '-d',
                              'auto_append_file=', '-r', PHP_METADATA], timeout)
        report['cli'] = dict(result, path=binary, status='ERROR')
        if result['ok']:
            try:
                metadata = json.loads(result['stdout'])
                if not isinstance(metadata, dict) or not all(
                        key in metadata for key in ('version', 'sapi', 'extensions')):
                    raise ValueError('Unexpected PHP metadata shape')
                report['cli']['metadata'] = metadata
                report['cli']['status'] = 'COLLECTED'
            except (ValueError, TypeError) as exc:
                report['cli']['error'] = str(exc)
    if fpm is not None:
        binary = shutil.which(fpm)
        report['fpm'] = {'status': 'NOT_FOUND'}
        if binary:
            result = run_command([binary, '-v'], timeout)
            report['fpm'] = dict(result, path=binary,
                                 status='COLLECTED_VERSION_ONLY' if result['ok'] else 'ERROR')
    return report


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--php', default='php', help='Trusted CLI executable/path')
    parser.add_argument('--fpm', help='Explicit trusted FPM executable/path (optional)')
    parser.add_argument('--timeout', type=int, default=10, help='Per-command seconds, 1..60')
    args = parser.parse_args(argv)
    if not 1 <= args.timeout <= 60:
        parser.error('--timeout must be in 1..60')
    report = collect(args.php, args.fpm, args.timeout)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    ok = report['cli']['status'] == 'COLLECTED'
    if args.fpm is not None:
        ok = ok and report['fpm']['status'] == 'COLLECTED_VERSION_ONLY'
    return 0 if ok else 2


if __name__ == '__main__':
    raise SystemExit(main())
