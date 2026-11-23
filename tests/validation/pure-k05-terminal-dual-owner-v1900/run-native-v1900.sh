#!/bin/sh
# Native PDP-6 proof/fix of terminal RAW+temporary PROCESS recovery.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=${V1900_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-terminal-dual-owner-v1900.XXXXXX")}
mkdir -p "$work"
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
  -S "$src/proc/vm_pdp6_swap.c" -o "$work/swap.s" >"$work/swap.compile" 2>&1
# Extend ONLY the historical testkit MM stub to accept a checked
# PROCESS target and optionally lose an actual successful free reply.
# The original production terminal VM and MM-facing assembler stays
# source-linked unchanged in the native guest.
python3 - "$kit/tests/validation/pure-ram-teardown-v1609/test-native-v1609.c" \
    "$here/test-native-v1900.c" "$work/fixture.c" <<'PYV1900'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='ascii')
old = 'int\nmm_free(kword_t base, unsigned int type, unsigned int owner)\n'
new = ('static int false_reply_v1900;\n'
       'static int refuse_type_v1900;\n' + old)
if src.count(old) != 1:
    raise SystemExit('original v1609 MM test stub signature changed')
src = src.replace(old, new, 1)
old = '        if (refuse_free_v1609)\n                return MM_ERR_BUSY;\n'
new = ('        if (refuse_free_v1609 || refuse_type_v1900 == (int)type)\n'
       '                return MM_ERR_BUSY;\n')
if src.count(old) != 1:
    raise SystemExit('original v1609 MM refusal stub changed')
src = src.replace(old, new, 1)
old = 'if (type != MM_TYPE_PACKED_PROCESS ||\n'
new = 'if ((type != MM_TYPE_PACKED_PROCESS &&\n                     type != MM_TYPE_PROCESS) ||\n'
if src.count(old) != 1:
    raise SystemExit('original MM stub source-only type predicate changed')
src = src.replace(old, new, 1)
old = '                --mm_extent_count;\n                return MM_OK;\n'
new = ('                --mm_extent_count;\n'
       '                if (false_reply_v1900 == (int)type) {\n'
       '                        false_reply_v1900 = 0;\n'
       '                        return MM_ERR_BUSY;\n'
       '                }\n'
       '                return MM_OK;\n')
if src.count(old) != 1:
    raise SystemExit('original MM stub deletion predicate changed')
src = src.replace(old, new, 1)
test = Path(sys.argv[2]).read_text(encoding='ascii')
Path(sys.argv[3]).write_text(
    '#define main v1609_historical_main\n' + src +
    '\n#undef main\n' + test, encoding='ascii')
PYV1900
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
  -S "$work/fixture.c" -o "$work/fixture.s" >"$work/fixture.compile" 2>&1 || {
      tail -65 "$work/fixture.compile" >&2
      exit 1
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
} > "$work/pure-terminal.s"
cat >"$work/pure-term-entry.s" <<'EOF'
        .text
        .globl proc_swap_term_v1666
proc_swap_term_v1666:
        jrst pdp6_pure_detach_v1609
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 40 \
    --workdir "$work/guest" --name daimos-k05-terminal-dual-owner-v1900 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/swap.s" "$work/vm-leaf.s" "$work/pure-term-entry.s" \
    "$work/pure-terminal.s" "$src/core/ret.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" "$work/fixture.s" \
    >"$work/native.log" 2>&1 || {
        tail -75 "$work/native.log" >&2
        echo "v1900 original terminal native failure evidence: $work" >&2
        exit 1
    }
echo "PASS v1900 original PDP6 exact two-owner terminal cleanup, pinned/foreign refusal: $work"

# Each unsafe branch is executed by the same native PDP-6 guest. An
# assembler/linker failure, instruction timeout or wrong assertion is
# NOT an accepted negative control.
python3 "$here/mutate-v1900.py" "$work/pure-terminal.s" "$work/unsafe"
for case in 'unsafe-source-pin-v1900 000000001103' \
    'unsafe-target-pin-v1900 000000001203' \
    'unsafe-target-length-v1900 000000001305' \
    'unsafe-uncertain-source-v1900 000000001714'; do
    set -- $case
    name=$1
    expected=$2
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 40 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/swap.s" "$work/vm-leaf.s" "$work/pure-term-entry.s" \
        "$work/unsafe/$name.s" "$src/core/ret.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" "$work/fixture.s" \
        >"$work/$name.log" 2>&1; then
        echo "FAIL v1900 unsafe native $name unexpectedly passed" >&2
        exit 1
    fi
    if ! grep -q "^FAIL: __test_exit: got $expected " "$work/$name.log"; then
        tail -65 "$work/$name.log" >&2
        echo "FAIL v1900 unsafe $name did not reach expected native assertion $expected" >&2
        exit 1
    fi
    echo "PASS v1900 original PDP-6 unsafe native $name rejected at $expected"
done
echo 'PASS v1900: four executed unsafe original terminal mutants rejected'
