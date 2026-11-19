#!/bin/sh
# Native PDP-6 KCORE detach + two-state PURE MRES terminal dispatcher.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-pure-bitmap-mres-v1667.XXXXXX")
trap 'echo "v1667 native terminal evidence: $work"' EXIT HUP INT TERM
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

if [ "${V1667_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-terminal-backend-v1666/run-v1666.sh" \
        >"$work/v1666-terminal-baseline.log" 2>&1
    echo 'v1667: original v1666/v1609 terminal native baseline PASS'
fi

python3 - "$kit/tests/validation/pure-ram-teardown-v1609/test-native-v1609.c" \
    "$here/test-native-v1667.c" "$work/test.c" <<'PY'
from pathlib import Path
import sys
original=Path(sys.argv[1]).read_text(encoding='ascii')
addition=Path(sys.argv[2]).read_text(encoding='ascii')
needle='int\nmain(void)\n'
if original.count(needle)!=1 or addition.count(needle)!=1:
    raise SystemExit('v1667 original v1609 test fixture main boundary drift')
Path(sys.argv[3]).write_text(original.replace(needle,
    'int\nretired_v1609_main(void)\n',1)+'\n'+addition,encoding='ascii')
PY

compile() {
    name=$1
    file=$2
    shift 2
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        "$@" $inc -S "$file" -o "$work/$name.s" \
        >"$work/$name-compile.log" 2>&1 || {
        tail -75 "$work/$name-compile.log" >&2
        exit 1
    }
}
compile test "$work/test.c"
compile kcore "$src/proc/vm_pdp6_swap.c"
compile dispatcher "$src/proc/proc_pure_term_v1667.c" \
    -DDAIMOS_PBM_V1667=1
compile terminal "$src/proc/proc_pure_bitmap_terminal_v1661.c" \
    -DDAIMOS_PURE_BITMAP_TERMINAL_V1661=1

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
} > "$work/raw-terminal.s"
cat > "$work/pure-entry.s" <<'EOF'
        .text
        .globl proc_swap_term_v1666
proc_swap_term_v1666:
        jrst proc_pure_term_v1667
EOF

run_guest() {
    name=$1
    dispatch=$2
    log=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/test.s" "$work/kcore.s" "$dispatch" \
        "$work/terminal.s" "$work/pure-entry.s" \
        "$work/raw-terminal.s" "$work/vm-leaf.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/core/ret.s" "$src/drivers/device_state.s" \
        >"$log" 2>&1
}
run_guest pure-bitmap-mres-v1667 "$work/dispatcher.s" \
    "$work/native.log" || { tail -75 "$work/native.log" >&2; exit 1; }
echo 'v1667: real C/ASM mode2 and bitmap mode3 terminal native PASS'

# Unsafe mutant: route mode3 to the old RAW-only leaf. The native
# oracle MUST notice the compressed owner is no longer handled.
python3 - "$src/proc/proc_pure_term_v1667.c" \
    "$work/unsafe-dispatch.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='ascii')
old='return proc_pure_bitmap_terminal_v1661((unsigned int)slot);'
if s.count(old)!=1:
    raise SystemExit('v1667 unsafe RAW-only dispatcher mutation drift')
Path(sys.argv[2]).write_text(s.replace(old,
    'return pdp6_pure_detach_v1609(slot, p, backing);',1),
    encoding='ascii')
PY
compile unsafe "$work/unsafe-dispatch.c" -DDAIMOS_PBM_V1667=1
if run_guest pure-bitmap-raw-mutant-v1667 "$work/unsafe.s" \
    "$work/mutant.log"; then
    echo 'FAIL v1667: RAW leaf accepted compressed owner' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant.log" || {
    tail -75 "$work/mutant.log" >&2; exit 1;
}
echo 'v1667: executed RAW-vs-bitmap dispatcher mutant rejected'
