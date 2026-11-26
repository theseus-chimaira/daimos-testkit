#!/usr/bin/env python3
"""Execute independent real PDP-6 Type-270 CLEAR and DATAO probes."""
import argparse
from pathlib import Path
import re
import subprocess
import os

def main():
    p = argparse.ArgumentParser()
    p.add_argument('simulator', type=Path)
    p.add_argument('prefix', type=Path)
    p.add_argument('work', type=Path)
    p.add_argument('--ka10', action='store_true')
    a = p.parse_args()
    a.work.mkdir()
    src = Path(__file__).with_name('probe-v1950.s')
    def run(*args):
        return subprocess.check_output([str(x) for x in args], text=True)
    run(a.prefix/'bin/das', '-F', '-C', '-O', a.work/'probe.dobj', src)
    run(a.prefix/'bin/dlink', '-b', '01000', '-o', a.work/'probe.dxr',
        '-M', a.work/'probe.map', a.work/'probe.dobj')
    run(a.prefix/'bin/dxrconvert', '--simh', '-b', '01000',
        a.work/'probe.dxr', a.work/'probe.rim')
    # dxrconvert emits a final GO, not just deposits. Never execute
    # before initializing the pushdown pointer or before selecting the
    # independent test entry point.
    rim = (a.work/'probe.rim').read_text().splitlines()
    assert rim[-1] == 'go 001000'
    assert all(line.startswith('deposit ') for line in rim[:-1])
    (a.work/'probe-deposits.ini').write_text('\n'.join(rim[:-1])+'\n')
    sym = dict(re.findall(r'(?m)^(\w+)\s+([0-7]{6})$', (a.work/'probe.map').read_text()))
    # Use a correctly sized private disk; no filesystem or OS is involved.
    disk = a.work/'dsk0.dsk'
    with disk.open('wb') as f:
        f.truncate(0o130000*128*8)
    bad = []
    for label in ('clear_test', 'reselect_test', 'dfr_test'):
        ini = a.work/(label+'.ini')
        setup = ('set cpu oneseg\nset cpu nomaoff\nset rpa disabled\n'
                 'set rpb disabled\nset rpc disabled\nset rpd disabled\n'
                 'set tua disabled\n') if a.ka10 else ''
        ini.write_text(setup + 'set cpu 32k\nset dpy disable\nset wcnsls disable\n'
                       'set ocnsls disable\nset dsk enabled\n'
                       f'attach -q dsk0 {disk}\ndo {a.work/"probe-deposits.ini"}\n'
                       'deposit 17 777700002000\n'
                       f'go {sym[label]}\nexamine 1\nexamine 2\nexit\n')
        r = subprocess.run([str(a.simulator), str(ini)], capture_output=True,
                           text=True, timeout=30, env=dict(os.environ, TERM='dumb'))
        log = r.stdout+r.stderr
        (a.work/(label+'.log')).write_text(log)
        ok = (r.returncode == 0 and log.count('HALT instruction') == 1 and
              re.search(r'(?m)^0*1:\s+0{12}\s*$', log) and
              re.search(r'(?m)^0*2:\s+000000040000\s*$', log))
        print(label, 'PASS' if ok else 'FAIL', flush=True)
        if not ok:
            bad.append(label)
    if bad:
        raise SystemExit('Failed: '+', '.join(bad))

if __name__ == '__main__':
    main()
