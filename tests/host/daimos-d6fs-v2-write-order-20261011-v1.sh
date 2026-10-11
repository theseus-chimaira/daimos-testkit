#!/bin/sh
# V2 staged-growth source contract; does not assert power-loss atomicity.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO is required}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
base=Path(sys.argv[1]); runtime=(base/'system/kernel/fs/d6fs_runtime.s').read_text(); mutation=(base/'system/kernel/fs/d6fs_provider_mutation.s').read_text()
write=runtime.split('d6fs_provider_write_words:',1)[1].split('d6fs_provider_write_words_fail:',1)[0]
resize=mutation.split('d6fs_resize_publish:',1)[1].split('d6fs_resize_published:',1)[0]
assert 'pushj   17,d6fs_provider_resize_fcb' in write
assert 'pushj   17,d6fs_reader_write_words' in write
assert write.index('pushj   17,d6fs_provider_resize_fcb') < write.index('pushj   17,d6fs_reader_write_words')
assert 'skipge  -4(17)' in resize and 'jrst    d6fs_resize_update_info' in resize
assert 'tlo     4,400000' in write and 'tlo     5,400000' in write
assert 'd6fs_provider_abort_staged_growth' in write
assert write.index('d6fs_reader_write_words') < write.index('d6fs_reader_put_fcb')
print('V2 STAGED GROWTH SOURCE CONTRACT PASS; crash-atomicity remains unproven')
PY
