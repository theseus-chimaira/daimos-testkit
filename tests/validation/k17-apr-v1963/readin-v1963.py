#!/usr/bin/env python3
"""Verify the counted tape and execute genuine Stage1 on KA10 to KINIT."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess


def main():
    p = argparse.ArgumentParser()
    for name in ('build', 'prefix', 'work'):
        p.add_argument(name, type=Path)
    a = p.parse_args()
    a.work.mkdir(parents=True)
    stage = a.build / 'stage1-dtc.dxr'
    tape = a.work / 'stage1-ka10.pt'
    dep = a.work / 'stage1.deposit'
    converter = str(a.prefix / 'bin/dxrconvert')
    subprocess.run([converter, '--ka10-readin', '-b', '060', str(stage), str(tape)], check=True)
    subprocess.run([converter, '--simh', '--no-go', '-b', '060', str(stage), str(dep)], check=True)
    expected = [int(l.split()[2], 8) for l in dep.read_text().splitlines()]
    raw = tape.read_bytes()
    assert len(raw) % 6 == 0 and all(b & 0o300 == 0o200 for b in raw)
    words = [sum((b & 0o77) << (30 - 6*j) for j, b in enumerate(raw[i:i+6]))
             for i in range(0, len(raw), 6)]
    assert words == [((-(len(expected)+1) & 0o777777) << 18) | 0o57,
                     *expected, 0o254000000060]
    for opts in (['--no-go', '-b', '060'], ['-b', '777777']):
        bad = a.work / 'bad.pt'
        r = subprocess.run([converter, '--ka10-readin', *opts, str(stage), str(bad)],
                           capture_output=True, text=True)
        assert r.returncode != 0 and not bad.exists(), r.stdout + r.stderr
    syms = dict(l.split() for l in (a.build / 'kinit.map').read_text().splitlines()
                if len(l.split()) == 2)
    entry = syms['kinit_enter']
    disk = a.work / 'dtc0.tap'
    shutil.copyfile(a.build / 'media/dtc0.tap', disk)
    ini = a.work / 'boot.ini'
    ini.write_text('set cpu 64k\nset cpu oneseg\nset cpu nomaoff\nset ptr enabled\n'
                   'set dct enabled\nset dtc dct=04\nset dtc enabled\nset dtc0 enabled\n'
                   f'attach -q ptr {tape}\nattach -q dtc0 {disk}\ndeposit ptr time 1\n'
                   f'break 060\nboot ptr\nexamine pc\nnobreak 060\nbreak {entry}\n'
                   'continue\nexamine pc\nexamine 040-041\nexit\n')
    with (a.work / 'console.log').open('wb') as out:
        subprocess.run([str(a.prefix / 'bin/pdp10-ka'), str(ini)], stdout=out,
                       stderr=subprocess.STDOUT, check=True, timeout=180)
    log = (a.work / 'console.log').read_text(errors='replace')
    assert 'Breakpoint, PC: 000060' in log and f'Breakpoint, PC: {entry}' in log, log
    assert 'Unknown command' not in log and 'HALT instruction' not in log, log
    print('PASS KA10 counted paper tape, relocated Stage1 and DTC KINIT entry', entry)


if __name__ == '__main__':
    main()
