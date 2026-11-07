#!/bin/sh
# Test-only activation of the actual PDP-6 BRK dispatch branch.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}; export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-brk-dispatch-v1000.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s" "$work/leaf.s" <<'PY'
from pathlib import Path
import os
import sys
s=Path(sys.argv[1]).read_text()
a=s.split('native_sys_brk:\n',1)[1].split('native_sys_ttyctl:\n',1)[0]
off = '.equ    PROC_OOM_BRK_ENABLED_V1000,0'
on = '.equ    PROC_OOM_BRK_ENABLED_V1000,1'
expected = os.environ.get('V1283_PRODUCTION_OOM_DEFAULT', '0')
assert expected in ('0', '1'), 'invalid production OOM expectation'
assert a.count(off) + a.count(on) == 1, 'ambiguous production OOM policy'
original = off if expected == '0' else on
assert a.count(original) == 1, 'unexpected production OOM policy'
a = a.replace(original, on, 1)
Path(sys.argv[2]).write_text('.text\n.globl native_sys_brk\nnative_sys_brk:\n'+a)
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode step --start 1000 --step-limit 90000 --timeout 20 \
 --workdir "$work/run" --name oom-brk-v1000 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
 "$self/daimos-oom-brk-dispatch-v1000.s" > "$work/log" 2>&1 || {
 tail -35 "$work/log" >&2; exit 1;
 }
echo 'v1000: only AC1=-1 and AC2=-1 enter fatal owner; other causes return PASS'
