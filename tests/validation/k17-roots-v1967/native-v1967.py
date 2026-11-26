#!/usr/bin/env python3
"""Native KA10 root profiles without auxiliary drum; verify actual provider."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import shutil
import subprocess


def boot(build, prefix, work, root):
    work.mkdir(parents=True)
    syms = {f[0]: int(f[1], 8) for l in (build / 'kcore.map').read_text().splitlines()
            if len(f := l.split()) == 2 and re.fullmatch('[0-7]+', f[1])}
    lines = []
    for line in (build / 'boot.ini').read_text().splitlines():
        if line.startswith(('attach -q dtc', 'attach -q dsk')):
            f = line.split()
            dest = work / (f[2] + Path(f[3]).suffix)
            shutil.copyfile(f[3], dest)
            line = 'attach -q ' + f[2] + ' ' + str(dest)
        elif line.startswith('set -q -n log '):
            line = 'set -q -n log ' + str(work / 'simh.log')
        if line == 'boot ptr':
            lines.append('expect "INIT V1" echo K17_ROOT_INIT')
        if line == 'exit':
            lines.extend(('examine RL', 'examine PL', 'examine 060-062'))
            if 'ka10_df10_cia' in syms:
                lines.append('examine 147-151')
            for name in ('vfs_namespace_root', 'backstore_blocks', 'backstore_blocks_used'):
                lines.append('examine %06o' % syms[name])
        lines.append(line)
    ini = work / 'boot.ini'
    assert not any('attach -q fha' in l for l in lines)
    ini.write_text('\n'.join(lines) + '\n')
    log = work / 'console.log'
    with log.open('wb') as out:
        subprocess.run(['timeout', '-k', '3s', '180s', 'stdbuf', '-o0', '-e0',
                        str(prefix / 'bin/pdp10-ka'), str(ini)],
                       stdout=out, stderr=subprocess.STDOUT, check=True)
    text = log.read_text(errors='replace')
    assert re.search(r'MACH\s+KA10', text) and re.search(r'MEM\s+64 K', text), text
    assert 'INIT V1K17_ROOT_INIT' in text, text
    assert not re.search(r'HALT instruction|device number conflict|Unknown command|\?RT|INIT: (RUN|RESPAWN) FAILED', text), text
    vals = {int(n, 8): int(v, 8) for n, v in re.findall(r'^([0-7]+):\s+([0-7]+)', text, re.M)}
    assert vals[syms['vfs_namespace_root']] >> 30 == root, text
    assert vals[syms['backstore_blocks_used']] == 0, text
    if 'ka10_df10_cia' in syms:
        assert syms['vm_pdp6_apr'] == 0o147
        assert syms['ka10_df10_cia'] == 0o150
        assert syms['ka10_df10_completion'] == 0o151
        rl = int(re.search(r'^RL:\s+([0-7]+)', text, re.M)[1], 8)
        pl = int(re.search(r'^PL:\s+([0-7]+)', text, re.M)[1], 8)
        assert vals[0o147] == (((pl & 0o776000) << 18) | rl), text
        assert vals[0o150] == vals[0o151] == 0, text
        print('PASS live APR and unused DF10 pair on root', root, flush=True)
    print('PASS native root', root, 'without drum; backstore blocks', vals[syms['backstore_blocks']], flush=True)


def main():
    p = argparse.ArgumentParser()
    for arg in ('tape', 'disk', 'prefix', 'work'):
        p.add_argument(arg, type=Path)
    a = p.parse_args()
    with ThreadPoolExecutor(max_workers=2) as pool:
        for f in (pool.submit(boot, a.tape, a.prefix, a.work / 'tape', 7),
                  pool.submit(boot, a.disk, a.prefix, a.work / 'disk', 6)):
            f.result()


if __name__ == '__main__':
    main()
