#!/bin/sh
# Verify mapped user buffers are released exactly once on every path.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
f = s.split('native_sys_d6fs_read_block:',1)[1].split('native_sys_settime:',1)[0]
assert 'jumpe   1,native_sys_d6fs_read_unmapped' in f
assert f.count('native_sys_map_one') == 1
assert f.count('jrst    native_sys_mapped_return') == 1
assert 'pushj   17,vm_user_mapping_release' not in f
assert 'native_sys_d6fs_read_bad:\n        seto    1,' in f
assert 'native_sys_d6fs_read_unmapped:\n        sub     17,kconst_2_2\n        jrst    kret_neg1' in f
assert 'native_sys_d6fs_read_done:\n        sub     17,kconst_2_2\n        jrst    native_sys_mapped_return' in f
print('daimos-d6fs-rawread-lifetime-v677: PASS (mapping lifetime gates)')
PY
