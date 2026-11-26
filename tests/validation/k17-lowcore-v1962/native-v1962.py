#!/usr/bin/env python3
"""Verify PDP-6 reclaimed low-core BSS and live APR/stack state."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess

HERE = Path(__file__).resolve().parent


def boot(build, work, prefix, port):
    work.mkdir(parents=True)
    maps = dict(line.split() for line in (build / 'kinit.map').read_text().splitlines()
                if len(line.split()) == 2)
    lines = []
    for line in (build / 'boot.ini').read_text().splitlines():
        if line.startswith(('attach -q dsk', 'attach -q dr', 'attach -q mtc')):
            continue
        if line.startswith('attach -q dtc'):
            f = line.split()
            dest = work / (f[2] + '.tap')
            shutil.copyfile(f[3], dest)
            line = 'attach -q ' + f[2] + ' ' + str(dest)
        elif line.startswith('attach -q -n '):
            f = line.split()
            line = 'attach -q -n ' + f[3] + ' ' + str(work / (f[3] + '.out'))
        elif line.startswith('set -q -n log '):
            line = 'set -q -n log ' + str(work / 'simh.log')
        if line == 'go 020':
            break
        lines.append(line)
    assert maps['vm_pdp6_apr'] == '000060'
    assert maps['mach_kernel_stack_base'] == '000061'
    entry = format(int(maps['kinit_lowcore_init'], 8) + 2, '06o')
    lines.extend(('break ' + entry, 'go 020', 'echo BEFORE_USER',
                  'examine 060-061', 'nobreak ' + entry,
                  'expect "INIT V1" echo K17_INIT_REACHED', 'continue',
                  'echo LIVE_USER', 'examine RL', 'examine PL'))
    lines.extend(('examine pc', 'examine 060-146', 'exit'))
    ini = work / 'physical.ini'
    ini.write_text('\n'.join(lines) + '\n')
    headless = work / 'headless.ini'
    subprocess.run(['sh', str(HERE.parents[1] / 'lib/daimos-simh-headless.sh'),
                    str(ini), str(headless), str(port), str(port + 12000)], check=True)
    with (work / 'console.log').open('wb') as out:
        subprocess.run(['timeout', '-k', '3s', '180s', 'stdbuf', '-o0', '-e0',
                        str(prefix / 'bin/pdp6'), str(headless)], cwd=build,
                       stdout=out, stderr=subprocess.STDOUT, check=True)
    verify(build, work / 'console.log')


def verify(build, path):
    maps = dict(line.split() for line in (build / 'kinit.map').read_text().splitlines()
                if len(line.split()) == 2)
    assert maps['vm_pdp6_apr'] == '000060'
    assert maps['mach_kernel_stack_base'] == '000061'
    log = path.read_text(errors='replace')
    assert 'Unknown command' not in log and 'HALT instruction' not in log, log
    assert 'K17_INIT_REACHED' in log and 'INIT V1' in log, log
    assert re.search(r'MEM\s+64 K', log), log
    early = log.split('BEFORE_USER', 1)[1].split('LIVE_USER', 1)[0]
    assert re.search(r'^60:\s+000000000000$', early, re.M), early
    assert re.search(r'^61:\s+000000000000$', early, re.M), early
    log = log.split('LIVE_USER', 1)[1]
    rl = int(re.search(r'^RL:\s+([0-7]+)', log, re.M)[1], 8)
    pl = int(re.search(r'^PL:\s+([0-7]+)', log, re.M)[1], 8)
    apr = int(re.search(r'^60:\s+([0-7]+)', log, re.M)[1], 8)
    mask = (0o776000 << 18) | 0o776000
    assert rl and (apr & mask) == (((pl & 0o776000) << 18) | rl)
    base = int(re.search(r'^61:\s+([0-7]+)', log, re.M)[1], 8)
    assert int(maps['__kcore_low_end'], 8) < base < 0o200000, oct(base)
    print('PASS reclaimed cells: initially zero; live APR %012o; idle stack %06o' % (apr, base), flush=True)
    observed = {int(a, 8): int(b, 8) for a, b in
                re.findall(r'^([0-7]+):\s+([0-7]{12})$', log, re.M)}
    expected = [int(w, 8) for w in (build / 'kcore.stream').read_text().splitlines()[2:55]]
    assert [observed[i] for i in range(0o62, 0o147)] == expected
    print('PASS native: all 53 decoder words match at 062-146', flush=True)


def main():
    p = argparse.ArgumentParser()
    for arg in ('lowmem', 'work', 'prefix'):
        p.add_argument(arg, type=Path)
    p.add_argument('--port', type=int, default=39163)
    p.add_argument('--replay', action='store_true')
    a = p.parse_args()
    if a.replay:
        verify(a.lowmem, a.work / 'raw/console.log')
    else:
        boot(a.lowmem, a.work / 'raw', a.prefix, a.port)


if __name__ == '__main__':
    main()
