#!/usr/bin/env python3
"""Ensure seven fixed-call sites are patched and shared DPY remains intact."""
from pathlib import Path
import re
import sys

root=Path(sys.argv[1])/'system/kernel'
src=(root/'fs/file_runtime.s').read_text()
minit=(root/'modules/module_minit.c').read_text()
mover=(root/'modules/module_runtime_pdp6.s').read_text()
names=['tty_write_s6rec','tty_read_s6rec','lpt_write_s6rec',
       'wcnsls_read_words','wcnsls_write_words','ttydpy_putchar','ttydpy_getchar']
for name in names:
    assert re.search(r'^'+name+r'_call:\s*\n\s*pushj\s+17,kret_neg1',src,re.M),name
    assert name+'_jump:' not in src,name
    assert '&'+name+'_call' in minit,name
    assert name+'_jump' not in minit,name
    if not name.startswith('ttydpy'):
        assert '.word   '+name+'_call' in mover,name
assert src.count('pushj   17,dpy_write_words_jump') == 2
assert 'dpy_write_words_jump:' in src
print('v708: seven optional KCORE direct-call bindings, shared DPY unchanged PASS')
