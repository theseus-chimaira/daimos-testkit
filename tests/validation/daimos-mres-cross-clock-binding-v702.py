#!/usr/bin/env python3
"""Validate six cross-MRES clock binding sites and KINIT export indices."""
from pathlib import Path
import re
import sys

root=Path(sys.argv[1]); kernel=root/'system/kernel'
minit=(kernel/'modules/module_minit.c').read_text()
mk=(root/'system/boot/pdp6/Makefile').read_text()
for path,names in {
    'fs/memfs_runtime.s':['clkbind_mfr0','clkbind_mfr1'],
    'fs/d6fs_runtime.s':['clkbind_dfr0','clkbind_dfr1'],
    'fs/d6fs_provider_mutation.s':['clkbind_dfm0'],
    'fs/d6fs_provider_namespace_pdp6.s':['clkbind_dfn0'],
}.items():
    source=(kernel/path).read_text()
    for sym in names:
        assert re.search(r'^'+sym+r':\s*\n\s*pushj\s+17,wall_time36\b',source,re.M),sym
        assert '-X '+sym in mk,sym
for index in [4,5,15,16,17,18]:
    assert 'minit_export(name, base, %dU), minit_clock_target()'%index in minit,index
assert 'wall_time36_provider_jump & KINIT_HALF_MASK' in minit
assert minit.count('minit_clock_target());')==6
print('v702: six clock calls, six exports, six KINIT direct patches PASS')
if len(sys.argv)>2:
    full=Path(sys.argv[2]); low=Path(sys.argv[3])
    mem=(full/'memfs-mres.map').read_text()
    d6=(low/'d6fs-mres.map').read_text()
    for name in ('clkbind_mfr0','clkbind_mfr1'):
        assert re.search(r'^'+name+r'\s+[0-7]+$',mem,re.M),name
    for name in ('clkbind_dfr0','clkbind_dfr1','clkbind_dfm0','clkbind_dfn0'):
        assert re.search(r'^'+name+r'\s+[0-7]+$',d6,re.M),name
    print('v702: full MEMFS and lowmem D6FS linked export maps PASS')
