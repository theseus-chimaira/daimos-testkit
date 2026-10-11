#!/bin/sh
# Verify V2 staged growth, while documenting the remaining non-atomic tail overwrite.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); rt=(root/'system/kernel/fs/d6fs_runtime.s').read_text(); mu=(root/'system/kernel/fs/d6fs_provider_mutation.s').read_text()
write=rt[rt.index('d6fs_provider_write_words:'):rt.index('d6fs_provider_write_words_fail:')]
resize=mu[mu.index('d6fs_provider_resize_fcb:'):mu.index('d6fs_resize_done:')]
assert write.index('pushj   17,d6fs_provider_resize_fcb') < write.index('pushj   17,d6fs_reader_write_words'), 'reassess ordering; implementation changed'
assert resize.index('d6fs_resize_publish:') < resize.index('skipge  -4(17)') < resize.index('pushj   17,d6fs_reader_put_fcb'), 'reassess staged FCB publication'
assert 'd6fs_provider_abort_staged_growth' in mu, 'staged rollback missing'
assert 'pushj   17,d6fs_reader_commit_cache' in rt[rt.index('d6fs_reader_write_transfer:'):rt.index('d6fs_reader_rw_done:')]
print('V2 ORDERED GROWTH PRESENT; still NOT CRASH-ATOMIC: in-place tail edits and per-block commits')
PY
