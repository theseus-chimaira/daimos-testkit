#!/bin/sh
# V2 source/format contradiction detector; does not assert power-loss safety.
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
assert 'pushj   17,d6fs_reader_put_fcb' in resize
print('KNOWN V2 ORDERING DEFECT: resize publishes FCB before payload; do not claim crash-atomicity')
PY
