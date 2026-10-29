#!/usr/bin/env python3
"""Check DSK/DRM read direct-binding contract and two write tails."""
from pathlib import Path
import re
import sys
root=Path(sys.argv[1])/'system/kernel'
minit=(root/'modules/module_minit.c').read_text()
mover=(root/'modules/module_runtime_pdp6.s').read_text()
for dev in ('dsk270','drm236'):
    asm=(root/'drivers'/(dev+'.s')).read_text()
    assert re.search(r'^'+dev+r'_read_call:\s*\n\s*jumpe\s+4,kret_neg1',asm,re.M)
    assert re.search(r'^'+dev+r'_write_jump:\s*\n\s*jrst\s+0',asm,re.M)
    assert dev+'_read_jump:' not in asm
    assert 'storage_patch_jump(&'+dev+'_read_call, read_service)' in minit
    assert 'storage_patch_jump(&'+dev+'_write_jump, write_service)' in minit
    assert '.word   '+dev+'_read_call' in mover
print('v710: two direct read branches and preserved write tails PASS')
