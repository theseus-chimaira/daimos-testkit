#!/bin/sh
# Assert the known unsafe D6FS append commit ordering until redesigned.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); rt=(root/'system/kernel/fs/d6fs_runtime.s').read_text(); mu=(root/'system/kernel/fs/d6fs_provider_mutation.s').read_text()
write=rt[rt.index('d6fs_provider_write_words:'):rt.index('d6fs_provider_write_words_fail:')]
resize=mu[mu.index('d6fs_provider_resize_fcb:'):mu.index('d6fs_resize_done:')]
assert write.index('pushj   17,d6fs_provider_resize_fcb') < write.index('pushj   17,d6fs_reader_write_words'), 'reassess ordering; implementation changed'
assert resize.index('d6fs_resize_publish:') < resize.index('pushj   17,d6fs_reader_put_fcb') < resize.index('d6fs_resize_update_info:'), 'reassess FCB publication'
assert 'pushj   17,d6fs_reader_commit_cache' in rt[rt.index('d6fs_reader_write_transfer:'):rt.index('d6fs_reader_rw_done:')]
print('KNOWN NONATOMIC: FCB size published before data; each block commits separately')
PY
