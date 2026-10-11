#!/bin/sh
# Static control-flow contract, NOT a device-I/O fault-injection acceptance.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must identify the tested kernel tree}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); run=(root/'system/kernel/fs/d6fs_runtime.s').read_text(); mut=(root/'system/kernel/fs/d6fs_provider_mutation.s').read_text()
write=run.split('d6fs_provider_write_words:',1)[1].split('d6fs_provider_write_words_done:',1)[0]
abort=mut.split('d6fs_provider_abort_staged_growth:',1)[1].split('d6fs_abort_stage_done:',1)[0]
checks={
 'stage before payload':write.index('pushj   17,d6fs_provider_resize_fcb') < write.index('pushj   17,d6fs_reader_write_words'),
 'full payload required': 'came    1,-1(17)' in write,
 'rollback on write error': 'd6fs_provider_write_words_store_fail:' in write and 'pushj   17,d6fs_provider_abort_staged_growth' in write,
 'FCB publication after payload': write.index('pushj   17,d6fs_reader_write_words') < write.index('pushj   17,d6fs_reader_put_fcb'),
 'old durable FCB read before cleanup': abort.index('pushj   17,d6fs_reader_fcb') < abort.index('pushj   17,d6fs_provider_free_file_tail'),
 'old allocated extent capacity computed': 'd6fs_abort_stage_capacity_loop:' in abort and 'add     7,2' in abort,
 'old FCB and info restored': abort.count('pushj   17,fs_copy_words') == 2,
 'rollback cleanup failure propagated': 'jumpn   1,d6fs_abort_stage_fail' in abort,
}
for label,valid in checks.items():
    print(('PASS' if valid else 'FAIL')+' staged rollback source contract: '+label)
if not all(checks.values()):
    raise SystemExit(1)
print('NOTE: source-only checks, NOT injected backing-write failure coverage')
PY
