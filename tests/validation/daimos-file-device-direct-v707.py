#!/usr/bin/env python3
"""Guard direct optional file-device calls and transient MINIT bindings."""
from pathlib import Path
import re
import sys

root=Path(sys.argv[1])/'system/kernel'
source=(root/'fs/file_runtime.s').read_text()
minit=(root/'modules/module_minit.c').read_text()
mover=(root/'modules/module_runtime_pdp6.s').read_text()
for device,operation in (('ptr','read'),('ptp','write'),('cr','read'),('cp','write')):
    call=f'{device}_{operation}_words_call'
    old=f'{device}_{operation}_words_jump'
    assert re.search(r'^'+call+r':\s*\n\s*pushj\s+17,kret_neg1',source,re.M),call
    assert old+':' not in source
    assert 'storage_patch_jump(&'+call+',' in minit
    assert '.word   '+call in mover
    assert old not in minit and old not in mover
print('v707: four directly patched optional file devices PASS')
