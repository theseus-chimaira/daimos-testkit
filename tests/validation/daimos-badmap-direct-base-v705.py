#!/usr/bin/env python3
"""Validate the direct BADMAP base-mapper call and KINIT export contract."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]); source = (root/'system/kernel/storage/badmap_dispatch.s').read_text()
make = (root/'system/boot/pdp6/Makefile').read_text()
minit = (root/'system/kernel/modules/module_minit.c').read_text()
assert re.search(r'badmap_map_block:\s*\nbadmap_base_map_call:\s*\n\s*pushj\s+17,badmap_direct_map',source)
assert 'badmap_base_map_jump:' not in source
assert 'badmap_base_map:' not in source
assert '-X badmap_base_map_call' in make
assert re.search(r'if \(members > 1U\)\s*storage_patch_module_jump\(base,[\s\S]*?minit_export\(name, base, 6U\),\s*module_service_get\(MODULE_SERVICE_BLOCKSET\)\)', minit)
print('v705: direct singleton mapper and optional BLOCKSET binding PASS')
