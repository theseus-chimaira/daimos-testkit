#!/bin/sh
# Known-bug audit: do not claim concurrency safety for open-time append.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); f=(root/'system/kernel/fs/file_runtime.s').read_text()
start=f.index('file_open_append:'); end=f.index('file_open_success:',start)
open_path=f[start:end]
start=f.index('file_words_common:'); end=f.index('file_words_result:',start)
write_path=f[start:end]
if 'FILE_O_APPEND' in open_path and 'st.size_words' in open_path and \
        'movem   1,1(13)' in open_path and 'move    2,1(010)' in write_path and \
        'FILE_O_APPEND' not in write_path:
    print('KNOWN UNSAFE: O_APPEND offset captured at open, not on write')
    raise SystemExit(0)  # detection passed; safety validation is still OPEN
raise SystemExit('append implementation changed; reassess concurrency before acceptance')
PY
