#!/usr/bin/env python3
"""Check actual linked boot layout against each permitted MRES set."""
import argparse
from pathlib import Path
import re
import subprocess


def symbols(path):
    result = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and re.fullmatch(r'[0-7]+', fields[1]):
            result[fields[0]] = int(fields[1], 8)
    return result


def verify(build, objdump, capacity):
    s = symbols(build/'kinit.map')
    k = symbols(build/'kcore.map')
    sizes = {}
    for p in sorted(build.glob('*-mres.dobj')):
        report = subprocess.check_output([str(objdump), '-h', str(p)], text=True)
        sizes[p.name] = int(re.search(r'\bresident=(\d+)', report)[1])
    alternatives = {'swapv481-mres.dobj', 'purev1612-mres.dobj',
                    'dtfs-mres.dobj', 'd6fs-mres.dobj',
                    'blockset-mres.dobj', 'badmap-mres.dobj'}
    common = sum(n for p, n in sizes.items() if p not in alternatives)
    branches = (
        common + sizes.get('swapv481-mres.dobj', 0) +
        sum(sizes.get(p, 0) for p in ('d6fs-mres.dobj',
            'blockset-mres.dobj', 'badmap-mres.dobj')),
        common + sizes.get('swapv481-mres.dobj', 0) +
        sizes.get('dtfs-mres.dobj', 0),
        common + sizes.get('purev1612-mres.dobj', 0) +
        sizes.get('dtfs-mres.dobj', 0))
    slot = k['__kcore_low_init_end'] - 0o60
    assert s['__kcore_load_end'] - s['__kcore_load_begin'] == slot
    assert s['__minit_table_begin'] == 0o30000
    unpadded = s['__minit_table_end'] + slot
    needed = k['__kcore_low_end'] + 2*capacity + max(branches)
    assert s['__kcore_load_end'] == max(unpadded, needed), (
        build, 'prefix bound', oct(s['__kcore_load_end']), oct(needed))
    print(f'PASS {build.name}: prefix {s["__kcore_load_end"]:06o}; '
          f'padding {s["__kcore_load_end"]-unpadded} words; '
          f'KCORE endpoint {k["__kcore_low_end"]:06o}', flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('repo', type=Path)
    p.add_argument('objdump', type=Path)
    p.add_argument('builds', type=Path, nargs='+')
    a = p.parse_args()
    header = (a.repo/'system/kernel/mm/mm.h').read_text()
    capacity = int(re.search(r'^#define\s+MM_MAX_EXTENTS\s+(\d+)', header, re.M)[1])
    for build in a.builds:
        verify(build, a.objdump, capacity)


if __name__ == '__main__':
    main()
