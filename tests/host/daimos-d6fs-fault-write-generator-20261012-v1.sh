#!/bin/sh
# Host validation of a TEST-ONLY assembler backing-write injector.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${TMPDIR:=$HOME/tmp}"
source="$DAIMOS_REPO/system/kernel/storage/fs_backing.s"
script=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)/tools/fault/d6fs-fault-write-v1.py
work=$(mktemp -d "$TMPDIR/daimos-d6fs-fault-write-20261012-v1.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
python3 "$script" "$source" "$work/fault.s" --logical 4660
"${DAS:-/usr/local/bin/das}" -F -C -O "$work/fault.dobj" "$work/fault.s"
python3 - "$source" "$work/fault.s" <<'PY'
from pathlib import Path
import sys
original=Path(sys.argv[1]).read_text()
faulted=Path(sys.argv[2]).read_text()
assert original.split('; int fs_backing_read(', 1)[1].split('; int fs_backing_write(', 1)[0] == faulted.split('; int fs_backing_read(', 1)[1].split('; int fs_backing_write(', 1)[0]
assert 'caie    2,11064' in faulted
assert 'jrst    kret_neg1' in faulted.split('fs_backing_write_fault_pass:', 1)[0]
assert faulted.count('fs_backing_write_fault_pass:') == 1
print('PASS test-only D6FS backing-write injector: valid assembly, read path unchanged')
PY

# The live interrupted-operation runner uses a separate *post-success* HALT
# selector, never a pre-write rejection. Ensure it assembles and does not
# modify the backing read path or ordinary source tree.
python3 "$script" "$source" "$work/postwrite-halt.s" --halt-after-first-word 0o123456701234
"${DAS:-/usr/local/bin/das}" -F -C -O "$work/postwrite-halt.dobj" "$work/postwrite-halt.s"
python3 - "$source" "$work/postwrite-halt.s" <<'PYTEST'
from pathlib import Path
import sys
original, faulted = (Path(name).read_text() for name in sys.argv[1:])
read_section = lambda s: s.split('; int fs_backing_read(', 1)[1].split('; int fs_backing_write(', 1)[0]
assert read_section(original) == read_section(faulted)
assert 'pushj   17,(4)' in faulted
assert 'camn    4,[123456701234]' in faulted
assert 'halt    .' in faulted
assert faulted.count('fs_backing_write_halt_done:') == 1
print('PASS test-only post-success HALT injector: assembled and backing read path unchanged')
PYTEST
