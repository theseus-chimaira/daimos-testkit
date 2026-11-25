#!/bin/sh
# Exercise the actual KCORE EXEC transaction with distinct old/staged owners.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k02-exec-stage-owner-v1719.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/proc/exec_lowmem_pdp6.s"
{
    printf '%s\n' '.text' '.globl exec_replace_current' \
        '.equ PROC_USER_MAP_BIT,2' \
        '.equ PROC_FDCTL_OFFSET,024' \
        '.equ PROC_CRED_OFFSET,066' \
        '.equ PROC_SWAP_BACKING_OFFSET,0406' \
        '.equ PROC_BRK_OFFSET,0407' \
        '.equ EXEC_LOAD_RT_REQUIRED,1' \
        '.equ EXEC_LOAD_NOMEM,-2'
    sed -n '/^        \.equ    EXEC_R_SAVE_FIRST/,/^        \.equ    EXEC_R_FRAME/p' "$src"
    sed -n '/^exec_replace_current:/,/^        ; Frame offsets relative to the fully advanced AC17/p' \
        "$src" | sed '$d'
    sed -n '/^sixbit_record_words:/,/^\/\*\*/p' \
        "$DAIMOS_REPO/system/kernel/proc/exec_load.s" | sed '$d'
    sed -n '/^proc_exec_hold_v1934:$/,/^        .bss$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s" | sed '$d'
    cat "$self/pure-exec-handover-v1934/nonpure-boundary-v1934.s"
} > "$work/production.s"

# A source-linked negative control must fail if the old backing is used when
# cleaning the staged VM after the old VM refuses release.
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
good = ('        move    4,EXEC_R_NEW_SWAP(17)\n'
        '        movem   4,(3)\n'
        '        hlrz    3,(16)\n'
        '        move    4,EXEC_R_NEW_EXT(17)\n'
        '        dpb     4,[POINT 4,PROC_CRED_OFFSET(3),8]\n'
        '        pushj   17,vm_space_destroy\n')
bad = ('        move    4,EXEC_R_OLD_SWAP(17)\n'
       '        movem   4,(3)\n'
       '        hlrz    3,(16)\n'
        '        move    4,EXEC_R_NEW_EXT(17)\n'
        '        dpb     4,[POINT 4,PROC_CRED_OFFSET(3),8]\n'
        '        pushj   17,vm_space_destroy\n')
assert source.count(good) == 1
Path(sys.argv[2]).write_text(source.replace(good, bad, 1))
PY

# Force the staged destructor itself to refuse. The only owner is the
# transient EXEC stack frame, so production must stop at HALT 4 instead
# of returning a superficially successful rollback to the old program.
python3 - "$self/daimos-k02-exec-stage-owner-v1719.s" "$work/refusal.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = 'mock_destroy_staged:\n        aos     destroy_staged_count\n'
new = (old + '        seto    1,\n'
       '        popj    17,\n')
assert source.count(old) == 1
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
PY

run_case()
{
    name=$1
    source=$2
    fixture=${3:-$self/daimos-k02-exec-stage-owner-v1719.s}
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 30 \
        --workdir "$work/run-$name" --name "k02-exec-stage-owner-v1719-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$fixture" "$source" \
        > "$work/$name.log" 2>&1
}

run_case production "$work/production.s" || {
    tail -65 "$work/production.log" >&2
    exit 1
}
if run_case unsafe "$work/unsafe.s"; then
    echo 'K02 v1719: wrong staged backing record mutation passed' >&2
    exit 1
fi
if run_case refusal "$work/production.s" "$work/refusal.s"; then
    echo 'K02 v1719: refused staged owner unexpectedly returned' >&2
    exit 1
fi
grep -q 'HALT instruction, PC: 000004' \
    "$work/run-refusal/k02-exec-stage-owner-v1719-refusal.report.txt" || {
    tail -55 "$work/refusal.log" >&2
    exit 1
}
echo 'K02 v1719: staged/old backing identity, loader/startup refusal, irreversible VM, wrong-backing mutant and HALT 4 refusal PASS'
