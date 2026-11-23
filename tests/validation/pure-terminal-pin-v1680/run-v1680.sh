#!/bin/sh
# Exercise original production PDP-6 C detach + assembler VM destroy,
# compact packed MM cleanup, and real storage mode publication.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-terminal-pin-v1680.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
incs="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$src/proc/vm_pdp6_swap.c" -o "$work/vm-pdp6-swap-v1609.s" \
    >"$work/compile-swap.log" 2>&1
{
    printf '#define main baseline_main_v1680\n'
    cat "$testkit/tests/validation/pure-ram-teardown-v1609/test-native-v1609.c"
    printf '#undef main\n'
    cat "$here/test-native-v1680.c"
} >"$work/test-merged-v1680.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$work/test-merged-v1680.c" -o "$work/test-native-v1609.s" \
    >"$work/compile-test.log" 2>&1
{
    printf '.text\n.globl vm_space_destroy\n'
    sed -n '/^vm_space_destroy:$/,/^\/\*\*$/p' \
        "$src/proc/vm_pdp6.s" | sed '$d'
} > "$work/vm-leaf-v1609.s"
{
    printf '.equ PROC_SWAP_TEXT_SHIFT,026\n'
    printf '.equ PROC_SWAP_TEXT_MASK,037777\n'
    printf '.equ PROC_SWAP_BACKING_OFFSET,0406\n'
    printf '.equ EXEC_USER_ORIGIN,020\n'
    cat "$src/proc/proc_pure_packed_detach_v1609.s"
} > "$work/packed-detach-v1609.s"

# v1666: terminal service is no longer resident in fixed KCORE.
# The real v1609 PURE leaf is an MRES export, reached from the
# KINIT-patched entry. These native tests set that patch target
# directly; v1666 KINIT selector tests verify the export mapping.
cat >"$work/pure-terminal-entry-v1666.s" <<'EOF'
        .text
        .globl proc_swap_term_v1666
proc_swap_term_v1666:
        jrst pdp6_pure_detach_v1609
EOF

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-ram-teardown-v1609 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/vm-pdp6-swap-v1609.s" "$work/vm-leaf-v1609.s" \
    "$work/pure-terminal-entry-v1666.s" \
    "$work/packed-detach-v1609.s" \
    "$src/core/ret.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-native-v1609.s"

echo 'PASS v1680: repeated pinned and refused MM-free terminal owner, peer preserved and eventual retry'
# Remove the original exact-MM pin predicate in test-only assembler.
# The new oracle must catch an unsafe attempt to call MM_FREE for a pin.
python3 - "$work/packed-detach-v1609.s" \
    "$work/unsafe-no-pin-guard-v1680.s" <<'PYV1680MUT'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='ascii')
old='''        and     7,[PPURE_META_PIN_MASK_V1609]
        jumpn   7,ppure_detach_bad_v1609
        hrrz    016,5'''
new='''        and     7,[PPURE_META_PIN_MASK_V1609]
        ; unsafe v1680: ignores ORIGINAL PACKED RAW pin guard.
        hrrz    016,5'''
if s.count(old) != 1:
    raise SystemExit('v1680 original MM pin guard anchor drift')
Path(sys.argv[2]).write_text(s.replace(old,new,1),encoding='ascii')
PYV1680MUT
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/unsafe" --name pure-terminal-pin-unsafe-v1680 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/vm-pdp6-swap-v1609.s" "$work/vm-leaf-v1609.s" \
    "$work/pure-terminal-entry-v1666.s" \
    "$work/unsafe-no-pin-guard-v1680.s" \
    "$src/core/ret.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-native-v1609.s" >"$work/unsafe.log" 2>&1; then
    echo 'FAIL v1680: unsafe pinned owner still called MM_FREE' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got 000000001102 ' "$work/unsafe.log"; then
    tail -65 "$work/unsafe.log" >&2
    echo 'FAIL v1680: pin mutant failed for wrong reason' >&2
    exit 1
fi
echo 'PASS v1680: executed unsafe original pin-guard mutant rejected'
echo "v1680 native evidence: $work"
