#!/bin/sh
# Source-link the complete production swap-in and BACKSTORE bitmap release.
# No mock free: the first attempt has an intentionally incomplete bitmap.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-in-checked-v1405.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel" "$work/production-v1405.s" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
swap = (root / 'proc/proc_swap_pdp6.s').read_text()
backing = (root / 'storage/backstore.s').read_text()

def leaf(source, first, last):
    if source.count(first) != 1:
        raise RuntimeError('ambiguous production start: ' + first)
    tail = source.split(first, 1)[1]
    if last not in tail:
        raise RuntimeError('missing production end: ' + last)
    return first + tail.split(last, 1)[0]

equ = [line for line in swap.splitlines()
       if re.match(r'^\s*\.equ\s+\w+\s*,', line)]
parts = [
    '.text',
    '\n'.join(equ),
    '.globl proc_swap_in\n.globl proc_swap_skip_words',
    '.globl backstore_verify_allocated_v795\n.globl backstore_free',
    leaf(swap, 'proc_swap_skip_words:\n', '\n.if PROC_SWAP_VERIFY_PURE'),
    leaf(swap, 'proc_swap_in:\n',
         '\n/* An impossible late mode mismatch'),
    leaf(backing, 'backstore_verify_allocated_v795:\n',
         '\n; int backstore_extend(first,old_blocks,new_blocks)'),
    leaf(backing, 'backstore_free:\n', '\n        .bss\n'),
]
Path(sys.argv[2]).write_text('\n\n'.join(parts) + '\n')
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/run" --name swap-in-checked-v1405 \
    --expect __test_exit=0 \
    --expect __rollback_calls_v1405=1 --expect __publish_calls_v1405=1 \
    --expect __invariant_calls_v1405=0 \
    --expect __read_calls_v1405=2 --expect __read_bad_v1405=0 \
    --expect __read_first_v1405=1 --expect __read_count_v1405=010 \
    --expect __read_base_v1405=0306000 \
    --expect __expect_calls_v1405=2 --expect __store_bad_v1405=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1405.s" \
    "$self/daimos-swap-in-checked-release-v1405.s" \
    > "$work/test.log" 2>&1 || {
        tail -65 "$work/test.log" >&2
        exit 1
    }
echo 'PASS v1405: source-linked PDP-6 swap-in release refusal rolls back MM'
echo 'PASS v1405: bitmap and DISK owner survive refusal, retry commits once'

# Executable negative control: if a future edit ignores the actual free
# return, this same fixture must reject the false successful publication.
python3 - "$work/production-v1405.s" "$work/unchecked-v1405.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        pushj   17,backstore_free\n'
       '        jumpn   1,proc_swap_in_free_fail\n')
if source.count(old) != 1:
    raise AssertionError('production swap-in release gate missing or moved')
Path(sys.argv[2]).write_text(source.replace(
    old, '        pushj   17,backstore_free\n'
         '        move    1,1\n', 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/unsafe" --name swap-in-unchecked-v1405 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/unchecked-v1405.s" \
    "$self/daimos-swap-in-checked-release-v1405.s" \
    > "$work/unsafe.log" 2>&1; then
    echo 'FAIL v1405: unchecked release mutation passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/unsafe.log" || {
    echo 'FAIL v1405: negative control did not reach its assertion' >&2
    tail -25 "$work/unsafe.log" >&2
    exit 1
}
echo 'PASS v1405: unchecked BACKSTORE release mutation rejected'
