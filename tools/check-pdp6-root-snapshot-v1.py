#!/usr/bin/env python3
"""Classify a DAIMOS fatal-root halt using linked KINIT symbol addresses.

Addresses are from the exact linked KINIT map; this is diagnostic evidence,
not proof of which internal mount operation returned an error.
"""
import argparse
import re
from pathlib import Path


def classify(log, mapping):
    raw = Path(log).read_text(errors='replace')
    symbols = {}
    for line in Path(mapping).read_text().splitlines():
        match = re.fullmatch(r'\s*(vfs_namespace_root|d6fs_active_reader|kinit_boot_handoff|vfs_mount_root)\s+([0-7]{6})\s*', line)
        if match:
            symbols[match.group(1)] = match.group(2)
    if set(symbols) != {'vfs_namespace_root', 'd6fs_active_reader', 'kinit_boot_handoff', 'vfs_mount_root'}:
        raise ValueError('linked KINIT diagnostic symbols missing')
    if not re.search(r'^\?RT\s*$', raw, re.M) or not re.search(r'^HALT instruction', raw, re.M):
        raise ValueError('no authenticated fatal root halt')
    def read(address):
        key = f'{int(address, 8):o}'
        found = re.findall(r'^'+re.escape(key)+r':\s*([0-7]{12})\s*$', raw, re.M)
        if len(found) != 1:
            raise ValueError('missing or ambiguous memory snapshot at '+address)
        return int(found[0],8)
    root = read(symbols['vfs_namespace_root'])
    reader = read(symbols['d6fs_active_reader'])
    handoff_addr = int(symbols['kinit_boot_handoff'],8)
    handoff = (read(f'{handoff_addr:o}'), read(f'{handoff_addr+1:o}'))
    mount_addr = int(symbols['vfs_mount_root'], 8)
    slots = [read(f'{mount_addr + i:o}') for i in range(4)]
    if any(slots):
        raise ValueError('VFS mount table is not empty')
    if root != 0:
        raise ValueError('snapshot does not establish an unmounted namespace')
    if reader == 0:
        raise ValueError('no active D6FS reader in snapshot')
    if handoff == ((1<<36)-1,)*2:
        raise ValueError('root selection handoff unresolved')
    return 'selected D6FS reader; all VFS mount slots and namespace root absent at fatal ?RT'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log');parser.add_argument('kinit_map')
    args=parser.parse_args()
    print(classify(args.log,args.kinit_map))


if __name__=='__main__':
    main()
