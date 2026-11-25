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

python3 - "$work/production.s" "$work/unsafe-map.s" "$work/unsafe-release.s" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text()
guard = ('        move    1,1(15)\n'
         '        camn    1,[-1]\n'
         '        jrst    exec_lowmem_fatal_v1720\n')
assert s.count(guard) == 1
Path(sys.argv[2]).write_text(s.replace(guard, '', 1))
release = ('exec_lowmem_fatal:\n'
           '        ; Live identity remains published even if VM teardown refused.\n'
           '        ; Fatal EXIT owns the remaining VM and must not inherit a map hold.\n'
           '        pushj   17,vm_user_mapping_release\n')
assert s.count(release) == 1
Path(sys.argv[3]).write_text(s.replace(
    release, release.replace('        pushj   17,vm_user_mapping_release\n', ''), 1))
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
if run_case unsafe-release "$work/unsafe-release.s"; then
    echo 'K02 v1720: leaked fatal EXIT mapping hold unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got' "$work/unsafe-release.log" || {
    tail -55 "$work/unsafe-release.log" >&2
    exit 1
}
echo 'K02 v1720: lowmem EXEC VM_NONE fatal, stable u-area, mapping release, 7 paths and 2 negative controls PASS'
