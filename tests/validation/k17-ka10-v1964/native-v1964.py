#!/usr/bin/env python3
"""Boot the production KA10 image to INIT and verify shared PDP-6 userland."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess


def symbols(path):
    return {f[0]: int(f[1], 8) for l in path.read_text().splitlines()
            if len(f := l.split()) == 2 and re.fullmatch('[0-7]+', f[1])}


def verify(ka, pdp6, log):
    k = symbols(ka / 'kcore.map')
    p = symbols(pdp6 / 'kcore.map')
    assert k['d6b_image_start_v1458'] == p['d6b_image_start_v1458'] == 0o62
    assert p['vm_pdp6_apr'] == 0o60 and p['mach_kernel_stack_base'] == 0o61
    for name in ('vm_pdp6_apr', 'mach_kernel_stack_base'):
        assert k['__kcore_low_init_end'] <= k[name] < k['__kcore_low_end']
    for name in ('init.dxr', 'login.dxr', 'dsh.dxr'):
        rel = Path('userland-build/userland') / name
        assert (ka / rel).read_bytes() == (pdp6 / rel).read_bytes(), name
    assert (ka / 'stage1-dtc.dxr').read_bytes() == (pdp6 / 'stage1-dtc.dxr').read_bytes()
    assert 'MACH' in log and re.search(r'MACH\s+KA10', log)
    assert re.search(r'MEM\s+64 K', log)
    assert re.search(r'DSK270\s+OK', log) and re.search(r'DTFS\s+LOADED', log)
    assert 'INIT V1K17_KA10_INIT_REACHED' in log
    assert not re.search(r'HALT instruction|device number conflict|Unknown command|\?RT|INIT: (RUN|RESPAWN) FAILED', log), log
    vals = {n: int(v, 8) for n, v in re.findall(r'^([0-7]+|RL|PL):\s+([0-7]+)', log, re.M)}
    assert vals['RL'] and vals['RL'] % 0o2000 == 0 and vals['PL'] % 0o2000 == 0o1777
    assert vals['61'] == 0o264000000000 | k['mach_unassigned_save']
    assert vals['41'] == 0o264000000000 | k['mach_syscall_save']
    expected = int((ka / 'kcore.stream').read_text().splitlines()[2], 8)
    assert vals['62'] == expected
    print('PASS native KA10 INIT; trap vectors; common Stage1 and PDP-6 user binaries', flush=True)


def main():
    p = argparse.ArgumentParser()
    for name in ('ka10', 'pdp6', 'prefix', 'work'):
        p.add_argument(name, type=Path)
    p.add_argument('--replay', type=Path)
    a = p.parse_args()
    if a.replay:
        verify(a.ka10, a.pdp6, a.replay.read_text(errors='replace'))
        return
    a.work.mkdir(parents=True)
    lines = []
    for line in (a.ka10 / 'boot.ini').read_text().splitlines():
        if line.startswith('attach -q dtc'):
            f = line.split()
            dest = a.work / (f[2] + '.tap')
            shutil.copyfile(f[3], dest)
            line = 'attach -q ' + f[2] + ' ' + str(dest)
        elif line.startswith('set -q -n log '):
            line = 'set -q -n log ' + str(a.work / 'simh.log')
        if line == 'boot ptr':
            lines.append('expect "INIT V1" echo K17_KA10_INIT_REACHED')
        if line == 'exit':
            lines.extend(('examine pc', 'examine RL', 'examine PL', 'examine 060-062', 'examine 040-041'))
        lines.append(line)
    ini = a.work / 'boot.ini'
    ini.write_text('\n'.join(lines) + '\n')
    log = a.work / 'console.log'
    with log.open('wb') as out:
        subprocess.run(['timeout', '-k', '3s', '180s', 'stdbuf', '-o0', '-e0',
                        str(a.prefix / 'bin/pdp10-ka'), str(ini)],
                       stdout=out, stderr=subprocess.STDOUT, check=True)
    verify(a.ka10, a.pdp6, log.read_text(errors='replace'))


if __name__ == '__main__':
    main()
