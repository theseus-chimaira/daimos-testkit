#!/bin/sh
# Test the exact source-linked KCORE FSINFO entry and actual userland loops.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fsinfo-mount-limit-v1492.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s" \
    "$work/fsinfo-v1492.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start = 'native_sys_fsinfo:\n'
end = '\n; PID-1/root storage activation policy.'
if source.count(start) != 1:
    raise ValueError('production FSINFO implementation not unique')
tail = source.split(start, 1)[1]
if end not in tail:
    raise ValueError('production FSINFO end marker moved')
Path(sys.argv[2]).write_text('.text\n.globl native_sys_fsinfo\n'
    + start + tail.split(end, 1)[0] + '\n')
PY

run_native() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 \
        --timeout 20 --workdir "$work/$label" --name "$label" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$source" "$self/daimos-fsinfo-mount-limit-v1492.s" \
        > "$work/$label.log" 2>&1
}

if ! run_native current "$work/fsinfo-v1492.s"; then
    tail -70 "$work/current.log" >&2
    exit 1
fi
echo 'PASS v1492: real KCORE FSINFO capacity query and old slot semantics'

# Negative control: corrupt the new count-query comparison and verify that
# normal out-of-range FSINFO semantics cannot impersonate capacity.
python3 - "$work/fsinfo-v1492.s" "$work/fsinfo-mutant-v1492.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = '        camn    2,[-1]\n'
if source.count(old) != 1:
    raise ValueError('production FSINFO capacity comparison moved')
Path(sys.argv[2]).write_text(source.replace(
    old, '        camn    2,[0]\n', 1))
PY
if run_native mutant "$work/fsinfo-mutant-v1492.s"; then
    echo 'FAIL v1492: legacy four-slot/out-of-range mutation accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/mutant.log" || {
    tail -50 "$work/mutant.log" >&2
    echo 'FAIL v1492: mutation was not rejected by the result assertion' >&2
    exit 1
}
echo 'PASS v1492: capacity query mutation rejected'

# Compile and execute the original userland MOUNTS/DF C functions, not
# reimplementations, with a deterministic mock FSINFO ABI and capacities.
python3 - "$DAIMOS_REPO/userland/exec/commands.c" \
    "$self/daimos-fsinfo-mount-limit-v1492-host.c" \
    "$work/commands-v1492.c" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
head, test_tail = Path(sys.argv[2]).read_text().split(
    '/* v1492 test entry follows source-injected command bodies. */', 1)
test = head
for name in ('cmd_mounts', 'cmd_df'):
    start = 'static int\n' + name + '('
    if source.count(start) != 1:
        raise ValueError('userland command implementation not unique: ' + name)
    body_tail = source.split(start, 1)[1]
    end = '\n}\n#endif'
    if end not in body_tail:
        raise ValueError('userland command implementation moved: ' + name)
    test += '\n' + start + body_tail.split(end, 1)[0] + '\n}\n'
test += '\n' + test_tail
Path(sys.argv[3]).write_text(test)
PY
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$work/commands-v1492" "$work/commands-v1492.c"
"$work/commands-v1492"
echo 'PASS v1492: exact MOUNTS/DF functions scan actual 1/4/8/26 slots'
