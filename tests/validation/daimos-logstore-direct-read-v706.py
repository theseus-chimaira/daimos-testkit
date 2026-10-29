#!/usr/bin/env python3
"""Guard both LOGSTORE read paths and KINIT binding indices."""
from pathlib import Path
import re
import sys

repo=Path(sys.argv[1]); src=(repo/'system/kernel/storage/logstore_runtime.s').read_text()
mk=(repo/'system/boot/pdp6/Makefile').read_text()
minit=(repo/'system/kernel/modules/module_minit.c').read_text()
assert re.search(r'logstore_backend_read_call:\s*\n\s*jumpe\s+5,kret_neg1\s*\nlogstore_backend_write_jump:\s*\n\s*jrst\s+0',src)
assert re.search(r'logstore_direct_read_call:\s*\n\s*jumpe\s+5,kret_neg1\s*\n\s*jrst\s+logstore_backend_write_jump',src)
assert 'logstore_backend_read_jump:' not in src
for label in ('logstore_backend_read_call','logstore_direct_read_call'):
    assert '-X '+label in mk
assert 'LOGSTORE_X_READ_CALL      2U' in minit
assert 'LOGSTORE_X_DIRECT_READ    4U' in minit
assert 'LOGSTORE_X_READ_CALL), read_addr' in minit
assert 'LOGSTORE_X_DIRECT_READ), read_addr' in minit
print('v706: LOGSTORE multi-member/direct read branch binding PASS')
