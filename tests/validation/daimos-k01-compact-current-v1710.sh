#!/bin/sh
# Real MM compactor: skip immovable current owner, preserve actual busy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-compact-current-v1710.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
    printf '%s\n' '.text' '.globl mm_compact' \
        '.equ MM_TYPE_PROCESS,1' '.equ MM_ALLOC_LOW,0' \
        '.equ VM_EXTENT_ALIGN_WORDS,02000'
    sed -n '/^mm_compact:$/,/^; int mm_alloc(words,type,owner,preference,basep)/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/production.s"
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
guard = ('''        skipn   proc_current_slot
        jrst    mm_compact_candidate_ready_v1710
        hrrz    3,2
        camn    3,proc_current_slot
        jrst    mm_compact_next
mm_compact_candidate_ready_v1710:
''')
assert s.count(guard) == 1
Path(sys.argv[2]).write_text(s.replace(guard, '', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 120000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-compact-current-v1710-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-compact-current-v1710.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -45 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'v1710: unsafe current-owner MM move unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1710: native PDP-6 current-owner skip, other-owner hard refusal, eligible move, mutant PASS'
