#!/bin/sh
# Real C KCORE terminal + PDP-6 MRES disk leaf and v1609 PURE leaf.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-terminal-v1666.XXXXXX")
trap 'echo "v1666 native terminal evidence: $work"' EXIT HUP INT TERM
incs="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

if [ "${V1666_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-ram-teardown-v1609/run-v1609.sh" \
        >"$work/v1609-baseline.log" 2>&1
    echo 'v1666: original RAW terminal v1609 native and mutant PASS'
fi

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$src/proc/vm_pdp6_swap.c" -o "$work/kcore-detach.s" \
    >"$work/kcore-build.log" 2>&1

python3 - "$kit/tests/validation/pure-ram-teardown-v1609/test-native-v1609.c" \
    "$here/test-native-v1666.c" "$src/proc/proc_swap_pdp6.s" \
    "$work/test-merged.c" "$work/disk-terminal.s" <<'PY'
from pathlib import Path
import sys
v1609=Path(sys.argv[1]).read_text(encoding='ascii')
test=Path(sys.argv[2]).read_text(encoding='ascii')
asm=Path(sys.argv[3]).read_text(encoding='ascii')
old='int\nmain(void)\n'
if v1609.count(old)!=1 or test.count(old)!=1:
    raise SystemExit('v1666 original fixture main boundary drift')
Path(sys.argv[4]).write_text(v1609.replace(old,
    'int\nretired_v1609_main(void)\n',1)+'\n'+test,encoding='ascii')
start='; Disk-only terminal owner retirement.'
end='        .equ    PROC_WORDS,3'
if asm.count(start)!=1 or asm.count(end)!=1:
    raise SystemExit('v1666 source MM disk leaf extraction drift')
body='; Disk-only terminal owner retirement.'+asm.split(start,1)[1].split(end,1)[0]
Path(sys.argv[5]).write_text('.text\n.globl proc_swap_mres_terminal_v1666\n'+body,
                             encoding='ascii')
PY

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$work/test-merged.c" -o "$work/test.s" \
    >"$work/test-build.log" 2>&1 || {
    tail -75 "$work/test-build.log" >&2; exit 1;
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -DDAIMOS_TEST_NO_BACKEND_V1666=1 \
    -S "$work/test-merged.c" -o "$work/test-no-backend.s" \
    >"$work/test-no-backend-build.log" 2>&1 || {
    tail -70 "$work/test-no-backend-build.log" >&2; exit 1;
}
{
    printf '.text\n.globl vm_space_destroy\n'
    sed -n '/^vm_space_destroy:$/,/^\/\*\*$/p' \
        "$src/proc/vm_pdp6.s" | sed '$d'
} > "$work/vm-leaf.s"
{
    printf '.equ PROC_SWAP_TEXT_SHIFT,026\n'
    printf '.equ PROC_SWAP_TEXT_MASK,037777\n'
    printf '.equ PROC_SWAP_BACKING_OFFSET,0406\n'
    printf '.equ EXEC_USER_ORIGIN,020\n'
    cat "$src/proc/proc_pure_packed_detach_v1609.s"
} >"$work/pure-terminal.s"

cat >"$work/disk-entry.s" <<'EOF'
        .text
        .globl proc_swap_term_v1666
proc_swap_term_v1666:
        jrst proc_swap_mres_terminal_v1666
EOF

# Copy the ACTUAL uninstalled JRST instruction; don't model the
# missing-MRES failure path with a function in C.
python3 - "$src/proc/proc_swap_entry_v481.s" \
    "$work/default-entry.s" "$work/unsafe-default.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='ascii')
old='proc_swap_term_v1666:\n        jrst kret_neg1'
if s.count(old)!=1:
    raise SystemExit('v1666 default terminal trampoline drift')
unit='.text\n.globl proc_swap_term_v1666\n'+old+'\n'
Path(sys.argv[2]).write_text(unit, encoding='ascii')
Path(sys.argv[3]).write_text(unit.replace('jrst kret_neg1',
    'jrst kret_zero',1),encoding='ascii')
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/native" --name pure-terminal-backend-v1666 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/kcore-detach.s" "$work/vm-leaf.s" \
    "$work/disk-entry.s" "$work/disk-terminal.s" \
    "$work/pure-terminal.s" "$src/core/ret.s" \
    "$src/mm/mm_pure_rebase_v1381.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" "$work/test.s" \
    >"$work/native.log" 2>&1 || {
    tail -65 "$work/native.log" >&2; exit 1;
}
echo 'v1666: production KCORE detach + source-extracted disk MRES native PASS'

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/no-backend" --name pure-terminal-uninstalled-v1666 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/kcore-detach.s" "$work/vm-leaf.s" \
    "$work/default-entry.s" "$work/disk-terminal.s" \
    "$work/pure-terminal.s" "$src/core/ret.s" \
    "$src/mm/mm_pure_rebase_v1381.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" "$work/test-no-backend.s" \
    >"$work/no-backend.log" 2>&1 || {
    tail -65 "$work/no-backend.log" >&2; exit 1;
}
echo 'v1666: original KCORE default stub refuses absent MRES PASS'

if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/default-mutant" \
    --name pure-terminal-uninstalled-mutant-v1666 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/kcore-detach.s" "$work/vm-leaf.s" \
    "$work/unsafe-default.s" "$work/disk-terminal.s" \
    "$work/pure-terminal.s" "$src/core/ret.s" \
    "$src/mm/mm_pure_rebase_v1381.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" "$work/test-no-backend.s" \
    >"$work/default-mutant.log" 2>&1; then
    echo 'FAIL v1666: absent backend returned successful detach' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/default-mutant.log" || {
    tail -65 "$work/default-mutant.log" >&2; exit 1;
}
echo 'v1666: executed unsafe absent-MRES success mutant rejected'

# Unsafe mutation: permit release despite a still-mapped VM APR.
# The independent test's live-APR guard must reject it.
python3 - "$work/disk-terminal.s" "$work/unsafe-mode.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='ascii')
old='        jumpn   4,swap_term_bad_v1666'
if s.count(old)!=1:
    raise SystemExit('v1666 MM disk mode mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old,
    '        move    4,4       ; unsafe ignore live APR',1),
    encoding='ascii')
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/mutant" --name pure-terminal-mode-mutant-v1666 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/kcore-detach.s" "$work/vm-leaf.s" \
    "$work/disk-entry.s" "$work/unsafe-mode.s" \
    "$work/pure-terminal.s" "$src/core/ret.s" \
    "$src/mm/mm_pure_rebase_v1381.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" "$work/test.s" \
    >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1666: disk MRES released live APR owner' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant.log" || {
    tail -60 "$work/mutant.log" >&2; exit 1;
}
echo 'v1666: executed unsafe live-APR mutant rejected'
