#!/bin/sh
# Source-linked PDP-6 tape clock tick, plus old-driver negative control.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tape-watchdog-v1089.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1089 work: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
work = Path(sys.argv[2])
tape = (root / 'system/kernel/drivers/tape_io.s').read_text()
start = 'tape_watchdog_tick_v1089:'
end = '/**\n * @brief Build the common Type 136'
assert tape.count(start) == 1 and tape.count(end) == 1
leaf = tape.split(start, 1)[1].split(end, 1)[0]
assert 'sosg    dtc_search_retries' in leaf
assert 'pushj   017,tape_transfer_wakeup' in leaf
import re
dtc = re.search(r'\.set TAPE_DTC_DATA_TIMEOUT_TICKS,([0-7]+)', tape)
mtc = re.search(r'\.set TAPE_MTC_DATA_TIMEOUT_TICKS,([0-7]+)', tape)
assert dtc and int(dtc.group(1), 8) == 300, 'DTC clock duration'
assert mtc and int(mtc.group(1), 8) == 5400, 'MTC clock duration'
(work / 'watchdog.s').write_text('.text\n.globl tape_watchdog_tick_v1089\n' + start + leaf)
mutated = leaf.replace('sosg    dtc_search_retries',
                       'skipg   dtc_search_retries', 1)
(work / 'unsafe.s').write_text('.text\n.globl tape_watchdog_tick_v1089\n' + start + mutated)
assert 'dtc_search_pi_setup:' in tape and 'mtc_rw_start:' in tape
assert ('movei 2,TAPE_DTC_DATA_TIMEOUT_TICKS\n'
        '        movem 2,dtc_search_retries') in tape
assert ('movei 2,TAPE_MTC_DATA_TIMEOUT_TICKS\n'
        '        movem 2,dtc_search_retries') in tape
assert tape.count('dtc_search_retries: .block 1') == 1
module = (root / 'system/kernel/modules/module_minit.c').read_text()
router = (root / 'system/kernel/storage/storage_router.s').read_text()
build = (root / 'system/boot/pdp6/Makefile').read_text()
assert '#define TAPE_X_WATCHDOG          5U' in module
assert 'storage_patch_jump(&storage_clock_tape_jump,' in module
assert 'minit_export(name, base, TAPE_X_WATCHDOG)' in module
assert 'storage_clock_tape_jump:\n        pushj 017,storage_clock_noop' in router
assert '-X tape_watchdog_tick_v1089' in build
print('v1089: clock/MINIT/export and shared-countdown wiring PASS')
PY
run_native() {
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 30000 --timeout 15 \
        --workdir "$work/run-$1" --name "tape-watchdog-v1089-$1" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-tape-data-watchdog-v1089.s" "$2" \
        > "$work/log-$1" 2>&1
}
run_native positive "$work/watchdog.s" || {
    tail -70 "$work/log-positive" >&2
    exit 1
}
if run_native negative "$work/unsafe.s"; then
    echo 'v1089: missing countdown decrement unexpectedly passed' >&2
    exit 1
fi
echo 'v1089: DTC/MTC read/write timeout, single completion, unrelated states and negative control PASS'
