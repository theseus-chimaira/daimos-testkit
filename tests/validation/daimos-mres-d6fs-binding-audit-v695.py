#!/usr/bin/env python3
"""Check D6FS physical-backend binding multiplicity and dynamic callbacks."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]) / 'system/kernel'
asm = (root / 'storage/fs_backing.s').read_text()
minit = (root / 'modules/module_minit.c').read_text()
make = (Path(sys.argv[1]) / 'system/boot/pdp6/Makefile').read_text()

names = ('fs_backing_direct_read_jump', 'fs_backing_direct_write_jump',
         'fs_backing_direct_drm_read_jump', 'fs_backing_direct_drm_write_jump')
for name in names:
    assert re.search(r'^' + name + r':\s*\n\s*jrst\s+(?:0|kret_neg1)\b', asm, re.M)
    assert len(re.findall(r'\bpushj\s+17,' + name + r'\b', asm)) == 1
    assert name in make
    print(f'{name}: one tail entry + one root-accounting PUSHJ')

assert re.search(r'jumpe\s+7,fs_backing_direct_read_jump', asm)
assert re.search(r'jumpe\s+7,fs_backing_direct_drm_read_jump', asm)
assert 'storage_patch_module_jump(base,' in minit
assert 'module_service_get(MODULE_SERVICE_DRM_READ_BLOCK)' in minit
assert 'module_service_get(MODULE_SERVICE_DRM_WRITE_BLOCK)' in minit
assert 'backing_ops = ((kword_t)direct_read << 18U)' in minit
assert re.search(r'fs_backing_read:.*?hlrz\s+4,4.*?jrst\s+\(4\)', asm, re.S)
assert re.search(r'fs_backing_write:.*?hrrz\s+4,4.*?jrst\s+\(4\)', asm, re.S)
print('v695: four shared entry slots; per-descriptor callback selection remains necessary: PASS')
