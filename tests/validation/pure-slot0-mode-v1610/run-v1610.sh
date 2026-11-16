#!/bin/sh
# Source-authentic PDP-6 slot-0 DISK/PACKED selection and refusal.
# Extract only the real MRES service leaf; use real two-bit mode ASM.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
root="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-slot0-mode-v1610.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$root/proc/proc_swap_pdp6.s" \
    "$root/proc/proc_storage_runtime_v30.s" "$work/service.s" <<'PY'
from pathlib import Path
import re
import sys
swap = Path(sys.argv[1]).read_text()
storage = Path(sys.argv[2]).read_text()
start = 'proc_swap_mres_service_v481:\n'
end = '\nproc_swap_mres_reclaim_v481:\n'
assert swap.count(start) == 1 and swap.count(end) == 1
start_storage = 'proc_storage_expect_v30:\n'
end_storage = '\n; int proc_storage_exchange_modes_v778'
assert storage.count(start_storage) == 1
assert storage.count(end_storage) == 1
equ = re.findall(r'(?m)^\s*\.equ\s+\w+,[^\n]+', swap)
source = ['.text',
          '.globl proc_swap_mres_service_v481',
          '.globl proc_storage_expect_v30',
          '.globl proc_storage_publish_v30']
source += equ
source += [start + swap.split(start, 1)[1].split(end, 1)[0]]
source += [start_storage + storage.split(
    start_storage, 1)[1].split(end_storage, 1)[0]]
Path(sys.argv[3]).write_text('\n'.join(source) + '\n')
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-slot0-mode-v1610 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/service.s" "$root/core/ret.s" \
    "$here/test-native-v1610.s"

# An unsafe test-only mutation treating PACKED as DISK must fail the
# executed counter/owner assertions, not merely a textual grep.
python3 - "$work/service.s" "$work/unsafe-v1610.s" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''        move    1,(17)
        movei   2,1                    ; PROC_STORAGE_DISK
        pushj   17,proc_storage_expect_v30
        jumpe   1,proc_swap_service_disk_v1610
'''
assert s.count(old) == 1, 'v1610: disk mode preflight drift'
Path(sys.argv[2]).write_text(s.replace(
    old, '''        jrst    proc_swap_service_disk_v1610
''', 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/unsafe" --name pure-slot0-unsafe-v1610 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/unsafe-v1610.s" "$root/core/ret.s" \
    "$here/test-native-v1610.s" >"$work/unsafe.log" 2>&1; then
    echo 'FAIL v1610: unsafe PACKED-to-DISK route was accepted' >&2
    exit 1
fi
grep -F 'FAIL: __test_exit' "$work/unsafe.log" >/dev/null || {
    cat "$work/unsafe.log"
    echo 'FAIL v1610: mutant did not reach executed assertion' >&2
    exit 1
}
echo 'PASS P1-E v1610: slot-0 DISK/PACKED ownership and unsafe mutation'
