#!/bin/sh
# Native PDP-6 BRK must not continue MM pressure after hard reclaim refusal.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-brk-reclaim-v1696.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    printf 'K01 debug files: %s\n' "$work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
vm="$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s"
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl vm_space_brk_current' \
        '.globl mm_arena_fits_v1260'
    sed -n '/^vm_space_brk_current:$/,/^vm_space_create:$/p' "$vm" | sed '$d'
    sed -n '/^mm_arena_fits_v1260:$/,/^; int mm_alloc_aligned(words/p' "$mm" | sed '$d'
} > "$work/production.s"
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = ('        camge   1,[-3]\n'
       '        jrst    vm_brk_reclaim_refused_v1696\n')
assert s.count(old) == 1, 'reclaim hard-refusal guard drift'
Path(sys.argv[2]).write_text(s.replace(old, '', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 250000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-brk-reclaim-v1696-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-brk-reclaim-v1696.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -45 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1696: unsafe repeated BRK pressure unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -45 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1696: native PDP-6 exact hard BRK -4/-5, bounded -1 fallback, no owner change and mutant PASS'
