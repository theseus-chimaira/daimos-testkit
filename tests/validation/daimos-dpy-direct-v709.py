#!/usr/bin/env python3
"""Validate direct DPY close/write calls and KINIT binding contract."""
from pathlib import Path
import re
import sys

root=Path(sys.argv[1])/'system/kernel'
s=(root/'fs/file_runtime.s').read_text()
m=(root/'modules/module_minit.c').read_text()
r=(root/'modules/module_runtime_pdp6.s').read_text()
for sym in ('dpy_close_words_call','dpy_write_words_call'):
    assert re.search(r'^'+sym+r':\s*\n\s*pushj\s+17,kret_neg1',s,re.M),sym
    assert 'storage_patch_jump(&'+sym+', address);' in m,sym
    assert '.word   '+sym in r,sym
assert 'dpy_write_words_jump:' not in s
assert 'address = minit_export(name, base, DPY_X_WRITE_WORDS);' in m
print('v709: two direct DPY calls and deferred mover bindings PASS')
