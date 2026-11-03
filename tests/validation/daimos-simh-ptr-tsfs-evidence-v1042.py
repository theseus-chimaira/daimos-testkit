#!/usr/bin/env python3
"""Validate a real SIMH PDP-6 paper-tape/TSFS build and captured boot.

Requires a completed `make image ROOT=tape BOOT=ptr` build and an actual
SIMH boot log. Recovered from the historical 2026-10-16 v1 testkit branch.
This is an opt-in evidence gate, not a substitute for running SIMH. A
synthetic or copied log is not proof of an actual successful boot.
"""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import sys


def check_dsh_literal_calls(source):
    text = source.read_text()
    calls = re.findall(
        r'\bdsh_s6_literal\(\s*&[A-Za-z_][A-Za-z_0-9]*\s*,\s*'
        r'([^\n]+?)\)\s*(?:==|!=)\s*0', text)
    if len(calls) < 5:
        raise ValueError('expected the five existing DSH literal callsites')
    for expression in calls:
        literals = re.findall(r'"([^"\n]*)"', expression)
        remainder = re.sub(r'"[^"\n]*"', '', expression).strip()
        if not literals or remainder not in ('', 'more ?  :'):
            raise ValueError('new DSH literal expression requires review: ' + expression)
        if any(value != value.upper() for value in literals):
            raise ValueError('DSH literal requires runtime case conversion: ' + expression)
    return len(calls)


def digest(path):
    hasher = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(65536), b''):
            hasher.update(chunk)
    return hasher.digest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True, help='DAIMOS source checkout')
    parser.add_argument('--build', type=Path, required=True, help='isolated PDP-6 image BUILD directory')
    parser.add_argument('--log', type=Path, required=True, help='captured SIMH console output')
    args = parser.parse_args()
    count = check_dsh_literal_calls(args.repo / 'userland/dsh/dsh.c')
    report = subprocess.run(['dxrcheck', str(args.build / 'userland-build/userland/dsh.dxr')],
                            capture_output=True, text=True, check=True).stdout
    match = re.search(r'\bDXR image=([0-7]+)\b', report)
    if match is None:
        raise ValueError('dxrcheck did not report the DSH image size')
    size = int(match.group(1), 8)
    limit = 0o36000
    if size > limit:
        raise ValueError('DSH exceeds unchanged EXEC limit: %06o > %06o' % (size, limit))
    config = (args.build / 'boot.ini').read_text()
    if 'deposit SW 2' not in config:
        raise ValueError('boot did not select the TSFS/tape root')
    for command in ('stage1-ptr.pt', 'ptr-boot1.pt', 'ptr-boot2.pt',
                    'expect "TAPE2"', 'go 060'):
        if command not in config:
            raise ValueError('SIMH paper-tape handoff missing: ' + command)
    media = args.build / 'media'
    tape = media / 'dtc0.tap'
    tsfs = media / 'tsfs-root0.dta'
    if not tape.is_file() or not tsfs.is_file() or tape.stat().st_size == 0:
        raise ValueError('TSFS DECtape root not populated')
    if digest(tape) != digest(tsfs):
        raise ValueError('mounted DECtape does not match the produced TSFS member')
    log = args.log.read_text(errors='replace')
    milestones = ('DTC', 'DTFS', 'INIT V1', 'LOGIN:')
    for marker in milestones:
        if marker not in log:
            raise ValueError('SIMH milestone not observed: ' + marker)
    if log.index('INIT V1') > log.index('LOGIN:'):
        raise ValueError('SIMH console event order invalid')
    print('DAIMOS SIMH PTR/TSFS evidence v1042: PASS, DSH=%06o <= %06o; '
          'literal callsites=%d; INIT and LOGIN observed' % (size, limit, count))
    print('Bounded console success only; user authentication and steady state remain unverified')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print('DAIMOS SIMH PTR/TSFS evidence v1042: FAIL: ' + str(exc), file=sys.stderr)
        sys.exit(1)
