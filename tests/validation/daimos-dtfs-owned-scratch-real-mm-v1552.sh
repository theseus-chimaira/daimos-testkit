#!/bin/sh
# Production MM allocator/pin/free leaves + real DTFS wrapper on PDP-6.
# Only the previously accepted v1551 physical device service is substituted.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-owned-real-mm-v1552.XXXXXX")
if [ "${V1552_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" \
    "$work/real-mm-v1552.s" <<'PY'
from pathlib import Path
import sys

source=Path(sys.argv[1]).read_text()

def leaf(first,last):
    assert source.count(first)==1,(first,source.count(first))
    assert source.count(last)==1,(last,source.count(last))
    return first + source.split(first,1)[1].split(last,1)[0]

decls = ('.text\n.globl mm_alloc_aligned_noreclaim\n'
         '.globl mm_extent_insert\n.globl mm_find_fit\n'
         '.globl mm_free\n.globl mm_pin\n.globl mm_unpin\n'
         '.globl mm_is_pinned\n')
constants='\n'.join(line for line in source.splitlines()
                    if line.startswith('        .equ    '))+'\n'
body=(
    leaf('mm_delete:\n','\n; Find a fitting free gap.') + '\n' +
    leaf('mm_find_fit:\n','\n; int mm_alloc_aligned_noreclaim') + '\n' +
    leaf('mm_alloc_aligned_noreclaim:\n','\n; Move one process extent') + '\n' +
    leaf('mm_free:\n','\n; int mm_process_transfer_pinned') + '\n' +
    leaf('mm_pin_adjust:\n','\n        .bss') + '\n'
)
for required in ('mm_find_base:', 'mm_extent_insert:',
                 'mm_alloc_nr_fit:', 'mm_free_busy:',
                 'mm_pin_add_ok:', 'mm_pin_sub:'):
    assert required in body
Path(sys.argv[2]).write_text(decls + constants + body)
print('v1552: extracted actual MM allocate/pin/unpin/free leaves')
PY

if ! "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 160000 --timeout 20 \
    --workdir "$work/run" --name dtfs-owned-real-mm-v1552 \
    --expect '__test_exit=0' \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-dtfs-owned-scratch-real-mm-v1552.s" \
    "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_owned_arm_v1552.s" \
    "$work/real-mm-v1552.s" > "$work/real-mm.log" 2>&1; then
    tail -65 "$work/real-mm.log" >&2
    echo 'FAIL v1552: actual MM allocator and DTFS scratch lease' >&2
    exit 1
fi
echo 'PASS v1552: REAL PDP-6 MM allocate/pin/arm/unpin/free twice, then shortage'
