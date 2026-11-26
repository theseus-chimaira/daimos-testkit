#!/usr/bin/env python3
"""Capture original swap counters and bitmap at each native CTY barrier."""
import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V = runpy.run_path(str(HERE.parent/'pure-runtime-reclaim-v1673/host-cty-v1673.py'))


def extra_snapshot(token, coremap, core, examine_word, examine_range):
    def read(name):
        return examine_word(V['source_symbol'](coremap, name))

    for name in ('proc_swap_blocks_used', 'backstore_blocks_used',
                 'backstore_enabled', 'proc_exec_resv_head_v1933',
                 'storage_state', 'storage_count'):
        read(name)
    ptr = read('backstore_bitmap')
    blocks = read('backstore_blocks')
    assert ptr and blocks and blocks <= 0o40000
    examine_range(ptr, (blocks + 35) // 36, core)
    for name in ('mfsdev_io_in', 'mfsdev_io_out', 'mfsdev_storage_errors'):
        examine_word(V['source_symbol'](coremap, name) +
                     (2 if name.endswith('errors') else 0o16))


if __name__ == '__main__':
    V['run'](sys.argv, extra_snapshot=extra_snapshot)
