#!/bin/sh
# D6FS append implementation contract; does not replace a two-writer test.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
f = (root / 'system/kernel/fs/file_runtime.s').read_text()
d = (root / 'system/kernel/fs/d6fs_runtime.s').read_text()
m = (root / 'system/kernel/fs/fs_mres.s').read_text()
header = (root / 'system/kernel/fs/file.h').read_text()
open_path = f[f.index('file_open_append:'):f.index('file_open_success:')]
write_path = f[f.index('file_words_common:'):f.index('file_write_words_tty:')]
result = f[f.index('file_words_append_result:'):f.index('file_words_done:')]
provider = d[d.index('d6fs_provider_write_words:'):d.index('d6fs_provider_write_words_fail:')]
checks = {
    'disjoint directory/append encoding':
        'FILE_META_APPEND           FILE_META_DIR' in header and
        'tlnn    1,000030' in open_path and 'tlo     1,100000' in open_path,
    'provider-side EOF dispatch':
        'tlnn    5,100000' in write_path and
        'tlnn    5,000030' in write_path and
        'caie    5,6' in write_path and 'seto    2,' in write_path,
    'atomic EOF resolved after FCB lookup':
        provider.index('pushj   17,d6fs_provider_fcb') <
        provider.index('camn    5,[-1]') <
        provider.index('move    5,-7(17)'),
    'serialized provider dispatch':
        'fs_provider_serialized:' in m and
        'pushj   17,(7)' in m and
        'fs_provider_unlock:' in m,
    'append descriptor cursor refreshed':
        'pushj   17,vfs_stat' in result and
        'movem   2,1(010)' in result,
    'append is not mistaken for directory':
        'file_readdir:' in f and
        'tlne    4,000030' in f[f.index('file_readdir:'):f.index('file_readdir_fail:')],
}
for label, passed in checks.items():
    if not passed:
        raise SystemExit('FAIL: ' + label)
print('D6FS atomic O_APPEND source contract PASS (live races separately)')
PY
