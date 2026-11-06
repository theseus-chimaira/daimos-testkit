#!/bin/sh
# Native PDP-6 execution of the exact diagnostic hooks in a disposable copy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-f07-dispatch-native-v1253.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/kernel/proc"
cp "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" "$work/kernel/proc/"
python3 "$self/daimos-f07-dispatch-tally-v1253.py" "$work/kernel"

python3 - "$work/kernel/proc/proc_pdp6.s" "$work/hooks.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start_dispatch = source.index('\nproc_sched_restore_selected:\n') + 1
end_dispatch = source.index('        movem   1,proc_current_slot\n',
                            start_dispatch) + len('        movem   1,proc_current_slot\n')
start_swap = source.index('\nproc_select_done_swap_v879:\n') + 1
end_swap = source.index('        iorm    1,proc_sched_cursor\n',
                        start_swap) + len('        iorm    1,proc_sched_cursor\n')
bss = source.index('\n        .globl daimos_f07u_dispatch_v1253\n',
                   source.index('\n        .bss\n'))
body = '''        .text
        .globl proc_sched_restore_selected
        .globl proc_select_done_swap_v879
'''
body += source[start_dispatch:end_dispatch] + '        popj    17,\n'
body += source[start_swap:end_swap] + '        popj    17,\n'
body += '\n        .bss\n' + source[bss:]
Path(sys.argv[2]).write_text(body)
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
    --workdir "$work/run" --name daimos-f07-dispatch-native-v1253 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/hooks.s" \
    "$self/daimos-f07-dispatch-native-v1253.s" > "$work/log" 2>&1 || {
        tail -60 "$work/log" >&2
        exit 1
    }
echo 'v1253: native PDP-6 exact dispatch, swap selection, and idle tallies PASS'
