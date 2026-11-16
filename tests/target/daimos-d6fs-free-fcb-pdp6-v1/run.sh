#!/bin/sh
# Link the current production FCB allocator against controlled reader results.
set -eu
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${TMPDIR:?set TMPDIR}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-d6fs-free-fcb-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' 0 1 2 3 15
src="$DAIMOS_REPO/system/kernel/fs/d6fs_provider_mutation.s"

# Extract exactly the live allocator. Its other neighbors have unrelated
# backing, extent and namespace dependencies which this test must not mock.
python3 - "$src" "$work/free-fcb.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
begin = source.index('d6fs_provider_free_fcb:\n')
end = source.index('        .globl  d6fs_provider_resize_fcb', begin)
Path(sys.argv[2]).write_text(
    '        .text\n        .globl d6fs_provider_free_fcb\n' +
    source[begin:end])
PY

"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -S "$here/test.c" -o "$work/test.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --timeout 15 --workdir "$work/run" \
    --name daimos-d6fs-free-fcb-pdp6-v1 \
    --expect daimos_d6fs_free_fcb_bound_v1_result=0 \
    "$here/start.s" "$work/test.s" "$work/free-fcb.s"

echo 'daimos-d6fs-free-fcb-pdp6-v1: PASS'
