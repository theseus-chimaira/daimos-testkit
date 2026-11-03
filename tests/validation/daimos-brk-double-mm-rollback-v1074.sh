#!/bin/sh
# Native PDP-6 branch test of the real BRK double-MM rollback path.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-brk-double-mm-rollback-v1074.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1074: retained $work"; fi' EXIT HUP INT TERM
src=${VM_SOURCE:-$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s}
python3 - "$src" "$work/rollback.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
begin = 'vm_brk_rollback_new_v1074:\n'
if begin in s:
    body = s.split(begin, 1)[1].split('\nvm_brk_commit:', 1)[0]
else:
    # The pre-fix control has no named rollback label; preserve its
    # original instructions for a failing negative-control run.
    anchor = '        ; Old mapping still owns the running process.'
    body = s.split(anchor, 1)[1].split('\nvm_brk_commit:', 1)[0]
    body = anchor + body
Path(sys.argv[2]).write_text('.text\n.globl vm_brk_rollback_new_v1074\n'
                              + begin + body + '\n')
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 15 \
    --workdir "$work/run" --name brk-double-mm-v1074 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/rollback.s" \
    "$self/daimos-brk-double-mm-rollback-v1074.s" >"$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v1074: BRK rollback exact cause, successful new free and invariant double refusal PASS'
