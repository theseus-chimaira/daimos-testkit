#!/usr/bin/env python3
"""Inventory installed MRES dispatch mechanisms without modifying DAIMOS."""
import re
import sys
from pathlib import Path


def main():
    root = Path(sys.argv[1])
    minit = (root / 'system/kernel/modules/module_minit.c').read_text()
    fs = (root / 'system/kernel/fs/fs_mres.s').read_text()
    runtime = (root / 'system/kernel/modules/module_runtime.c').read_text()
    mover = (root / 'system/kernel/modules/module_runtime_pdp6.s').read_text()
    makefile = (root / 'system/boot/pdp6/Makefile').read_text()

    # This count includes repeated call sites, not independent bindings.
    patched = len(re.findall(r'\bstorage_patch_jump\s*\(', minit)) - 1
    module_patched = len(re.findall(r'\bstorage_patch_module_jump\s*\(', minit)) - 1
    assert patched > 40 and module_patched > 0
    assert 'module_runtime_move' in mover
    assert 'currently wired into MM compaction' in runtime
    assert 'module_runtime.c' in makefile
    assert 'module_runtime_pdp6.s' not in makefile
    assert 'fs_provider_reg_call:' in fs
    assert 'fs_mres_vector_dispatch:' in fs
    assert 'fs_mres_context_vector_dispatch:' in fs

    providers = ['memfs', 'dtfs', 'd6fs', 'tsfs']
    for provider in providers:
        assert f'fs_{provider}_service_jump:' in fs
        assert f'&fs_{provider}_service_jump' in minit

    print('v689 MRES dispatch inventory')
    print('  KINIT source direct patch-call occurrences:', patched)
    print('  KINIT module-local patch-call occurrences:', module_patched)
    print('  Filesystem provider slots:', len(providers))
    print('  Shared filesystem operation decoders: 2')
    print('  Runtime mover present in source: yes')
    print('  Runtime mover linked by boot Makefile: no')
    print('  No general MRES dispatch removal justified without per-site analysis')


if __name__ == '__main__':
    main()
