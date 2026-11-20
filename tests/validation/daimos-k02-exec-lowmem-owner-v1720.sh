#!/bin/sh
# Source-linked native low-memory EXEC ownership, with two negative controls.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k02-exec-lowmem-owner-v1720.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/proc/exec_lowmem_pdp6.s"
{
    printf '%s\n' '.text' '.globl exec_replace_current_lowmem' \
        '.equ EXEC_LAUNCH_MM_OWNER,013' \
        '.equ MM_TYPE_KERNEL_DYNAMIC,3' \
        '.equ PROC_FDCTL_OFFSET,024' \
        '.equ PROC_SWAP_BACKING_OFFSET,0406' \
        '.equ PROC_CRED_OFFSET,066' \
        '.equ PROC_BRK_OFFSET,0407' \
        '.equ EXEC_LOAD_RT_REQUIRED,1'
    sed -n '/^        ; Frame offsets relative to the fully advanced AC17\./,$p' "$src"
    sed -n '/^sixbit_record_words:/,/^\/\*\*/p' \
        "$DAIMOS_REPO/system/kernel/proc/exec_load.s" | sed '$d'
} > "$work/production.s"

python3 - "$work/production.s" "$work/unsafe-map.s" "$work/unsafe-meta.s" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()
guard = ('        move    1,1(15)\n'
         '        camn    1,[-1]\n'
         '        jrst    exec_lowmem_fatal_v1720\n')
assert s.count(guard) == 1
Path(sys.argv[2]).write_text(s.replace(guard, '', 1))
restore = ('exec_lowmem_fatal:\n'
           '        ; The replacement loader runs directly on the current descriptor.\n')
assert s.count(restore) == 1
restore_body = ('        move    1,EXEC_LM_META(17)\n'
                '        movem   1,(15)\n'
                '        movni   16,2')
assert s.count(restore_body) == 1
Path(sys.argv[3]).write_text(s.replace(
    restore_body, '        movni   16,2', 1))
PY

run_case()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 400000 --timeout 30 \
        --workdir "$work/run-$name" --name "k02-exec-lowmem-v1720-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k02-exec-lowmem-owner-v1720.s" "$source" \
        > "$work/$name.log" 2>&1
}

run_case production "$work/production.s" || {
    tail -75 "$work/production.log" >&2
    exit 1
}
if run_case unsafe-map "$work/unsafe-map.s"; then
    echo 'K02 v1720: resuming old VM_NONE unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got' "$work/unsafe-map.log" || {
    tail -55 "$work/unsafe-map.log" >&2
    exit 1
}
if run_case unsafe-meta "$work/unsafe-meta.s"; then
    echo 'K02 v1720: lost fatal EXIT u-area owner unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got' "$work/unsafe-meta.log" || {
    tail -55 "$work/unsafe-meta.log" >&2
    exit 1
}
echo 'K02 v1720: lowmem EXEC VM_NONE fatal, u-area restore, 7 paths and 2 negative controls PASS'
