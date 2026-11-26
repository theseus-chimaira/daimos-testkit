#!/usr/bin/env python3
"""Physical PDP-6 paper-tape/DECtape read-in and low-core regression."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess

from concurrent.futures import ThreadPoolExecutor

HERE = Path(__file__).resolve().parent


def boot(build, work, prefix, mode, port):
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
    if mode == 'compressed':
        entry = maps['kinit_enter']
        lines.append('break ' + entry)
    else:
        lines.append('expect "INIT V1" echo K17_INIT_REACHED')
    lines.extend(('go 020', 'examine pc', 'examine 060-146', 'exit'))
    ini = work / 'physical.ini'
    ini.write_text('\n'.join(lines) + '\n')
    headless = work / 'headless.ini'
    subprocess.run(['sh', str(HERE.parents[1] / 'lib/daimos-simh-headless.sh'),
                    str(ini), str(headless), str(port), str(port + 12000)], check=True)
    with (work / 'console.log').open('wb') as out:
        subprocess.run(['timeout', '-k', '3s', '180s', 'stdbuf', '-o0', '-e0',
                        str(prefix / 'bin/pdp6'), str(headless)], cwd=build,
                       stdout=out, stderr=subprocess.STDOUT, check=True)
    log = (work / 'console.log').read_text(errors='replace')
    assert 'Unknown command' not in log and 'HALT instruction' not in log, log
    if mode == 'compressed':
        assert 'Breakpoint, PC: ' + entry in log, log
    else:
        assert 'K17_INIT_REACHED' in log and 'INIT V1' in log, log
        assert re.search(r'MEM\s+64 K', log), log
    observed = {int(a, 8): int(b, 8) for a, b in
                re.findall(r'^([0-7]+):\s+([0-7]{12})$', log, re.M)}
    expected = [int(w, 8) for w in (build / 'kcore.stream').read_text().splitlines()[2:55]]
    assert [observed[i] for i in range(0o62, 0o147)] == expected
    print('PASS native %s: all 53 decoder words match at 062-146' % mode, flush=True)


def main():
    p = argparse.ArgumentParser()
    for arg in ('full', 'lowmem', 'work', 'prefix'):
        p.add_argument(arg, type=Path)
    p.add_argument('--port', type=int, default=39163)
    a = p.parse_args()
    with ThreadPoolExecutor(max_workers=2) as pool:
        tests = (pool.submit(boot, a.full, a.work / 'compressed', a.prefix,
                             'compressed', a.port),
                 pool.submit(boot, a.lowmem, a.work / 'raw', a.prefix,
                             'raw', a.port + 1))
        for test in tests:
            test.result()


if __name__ == '__main__':
    main()
