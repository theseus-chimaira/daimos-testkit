#!/usr/bin/env python3
"""Validate a built PDP-6 PTR/TSFS SIMH boot without a wall-time assumption.

This checks boot artifacts and logged boot milestones, not login success or
unmeasured AAP transport equivalence. Pass the isolated build directory and
its captured SIMH console log explicitly.
"""
import argparse
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--simh-log', type=Path, required=True)
    parser.add_argument('--dsh-source', type=Path, required=True)
    args = parser.parse_args()
    b = args.build
    source = args.dsh_source.read_text()
    fn = re.search(r'static int\s+dsh_s6_literal\s*\([^)]*\)\s*\{(.*?)\n\}', source, re.S)
    assert fn, 'missing DSH literal helper'
    for name in ('HISTFILE', 'HOME', 'PS1', 'PS2', '/CONFIG/DSH.PROFILE'):
        assert '"' + name + '"' in source, 'missing expected uppercase callsite: ' + name
    assert "ch >= 'a'" not in fn.group(1), 'runtime case conversion reintroduced'
    dsh = b/'userland-build/userland/dsh.dxr'
    check = subprocess.run(['dxrcheck', str(dsh)], text=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    match = re.search(r'\bDXR image=([0-7]+)', check.stdout)
    assert match, 'no image size in dxrcheck'
    size = int(match.group(1), 8)
    assert size <= 0o36000, 'DSH exceeds EXEC image ceiling: %06o' % size
    for path in (b/'stage1-ptr.pt',b/'media/ptr-boot1.pt',
                 b/'media/ptr-boot2.pt',b/'media/dtc0.tap'):
        assert path.is_file() and path.stat().st_size > 100, 'missing boot medium: ' + str(path)
    ini = (b/'boot.ini').read_text()
    assert 'deposit SW 2' in ini, 'not configured for TSFS root switch'
    assert 'expect "TAPE2"' in ini, 'no second paper-tape handoff'
    assert 'attach -q dtc0 ' in ini, 'TSFS DECtape root missing'
    log = args.simh_log.read_text(errors='replace')
    for marker in ('DTC', 'DTFS', 'INIT V1', 'LOGIN:'):
        assert marker in log, 'SIMH boot did not reach ' + marker
    assert 'SIGTERM' not in log or 'LOGIN:' in log.split('SIGTERM')[0], 'login not reached before timeout'
    print('PASS: DSH=%06o, PTR/TSFS media and SIMH startup through LOGIN confirmed' % size)
    print('NOT PROVEN: interactive login, steady state, or AAP Type-555 TSFS compatibility')


if __name__ == '__main__':
    main()
