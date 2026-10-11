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
