#!/bin/sh
# Verify actual EXEC launch-copy free and reject unsafe ignored MM release.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-exec-launch-free-v1706.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/proc/exec_lowmem_pdp6.s"
{
    printf '%s\n' '.text' '.globl exec_lowmem_free' \
        '.equ EXEC_LM_LAUNCH,-001' \
        '.equ MM_TYPE_KERNEL_DYNAMIC,3' \
        '.equ EXEC_LAUNCH_MM_OWNER,013'
    sed -n '/^exec_lowmem_free:$/,/^exec_lowmem_alloc_fail:$/p' "$src" | sed '$d'
} > "$work/production.s"
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
guard = '        jumpn   1,proc_swap_storage_invariant_v30\n'
assert s.count(guard) == 1
Path(sys.argv[2]).write_text(s.replace(
    guard, '        jumpn   1,exec_lowmem_return\n', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-exec-launch-free-v1706-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-exec-launch-free-v1706.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -55 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1706: dropped EXEC MM owner mutation unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -45 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1706: actual EXEC launch MM success, exact -4/-5 invariant stop and unsafe mutant PASS'
