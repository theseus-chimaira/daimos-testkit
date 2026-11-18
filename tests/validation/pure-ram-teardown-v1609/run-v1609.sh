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
work=$(mktemp -d "$TMPDIR/pure-teardown-v1609.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
incs="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$src/proc/vm_pdp6_swap.c" -o "$work/vm-pdp6-swap-v1609.s" \
    >"$work/compile-swap.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$here/test-native-v1609.c" -o "$work/test-native-v1609.s" \
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

# Remove the saved-backing identity comparison only in a private test
# candidate. The original negative test MUST catch it at runtime:
# a malformed PACKED record must never free the wrong raw suffix.
python3 - "$work/packed-detach-v1609.s" \
    "$work/unsafe-detach-v1609.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
old = '''        move    6,PROC_SWAP_BACKING_OFFSET(5)
        came    6,012
        jrst    ppure_detach_bad_v1609
'''
assert source.count(old) == 1, "v1609: MM owner source check drift"
Path(sys.argv[2]).write_text(source.replace(
    old, '''        ; Unsafe test-only mutant: ignore saved executable identity.
''', 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/mutant" --name pure-ram-teardown-unsafe-v1609 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/vm-pdp6-swap-v1609.s" "$work/vm-leaf-v1609.s" \
    "$work/pure-terminal-entry-v1666.s" \
    "$work/unsafe-detach-v1609.s" "$src/core/ret.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-native-v1609.s" >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1609: unsafe backing mutation was accepted' >&2
    exit 1
fi
if ! grep -F 'FAIL: __test_exit' "$work/mutant.log" >/dev/null; then
    cat "$work/mutant.log"
    echo 'FAIL v1609: mutant failed without executed assertion' >&2
    exit 1
fi
echo 'PASS P1-E v1609: real VM destroy / packed MM owner cleanup'
echo 'PASS P1-E v1609: unsafe backing comparison mutation rejected'
