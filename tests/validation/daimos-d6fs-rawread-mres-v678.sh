#!/bin/sh
# Link-safe RO raw block inspection must use removable D6FS provider.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); k=(r/'system/kernel/proc/syscall_dispatch_pdp6.s').read_text()
m=(r/'system/kernel/fs/d6fs_runtime.s').read_text()
f=k.split('native_sys_d6fs_read_block:',1)[1].split('native_sys_d6fs_read_done:',1)[0]
assert 'blockset_read_block' not in f
assert 'movei   6,026' in f and 'movei   7,6' in f
assert 'pushj   17,fs_provider_reg_call' in f
assert 'cain    6,026' in m and 'jrst    d6fs_provider_recovery_read' in m
g=m.split('d6fs_provider_recovery_read:',1)[1].split('; Return exact filesystem capacity',1)[0]
assert 'fs_backing_read' in g
print('daimos-d6fs-rawread-mres-v678: PASS')
PY
