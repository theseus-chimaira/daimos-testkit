#!/bin/sh
# Native PDP-6: production swap-in/rollback through production DEVICE bridge.
# Only the final DSK270 sector hardware endpoint is modeled by the test.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-in-device-v1319.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1319 work: $work"; fi' EXIT HUP INT TERM

# Reuse the independently accepted original native v1317 extraction;
# do not fork, hand-rewrite or mutate production transaction leaves.
KEEP_TEST=1 sh "$self/daimos-swap-in-real-transaction-v1316.sh" \
    > "$work/v1317-regression.log" 2>&1 || {
    tail -45 "$work/v1317-regression.log" >&2
    exit 1
}
baseline=$(sed -n 's/^v1316 work: //p' "$work/v1317-regression.log" | tail -1)
test -n "$baseline" && test -f "$baseline/production-v1316.s"
cp "$baseline/production-v1316.s" "$work/production-v1319.s"

python3 - "$self/daimos-swap-in-real-transaction-v1316.s" \
    "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work" <<'PY'
from pathlib import Path
import sys

source, gateway, work = (Path(p) for p in sys.argv[1:])
fixture = source.read_text()
gateway = gateway.read_text()

start = '        .globl backstore_read\nbackstore_read:\n'
end = '        .globl proc_swap_reload_pure\n'
assert fixture.count(start) == 1 and fixture.count(end) == 1
before, remainder = fixture.split(start, 1)
_, after = remainder.split(end, 1)

# The real bridge validates the 8-block request, translates DEVICE
# block 1 through physical start 020, and performs eight sector calls.
label_start = 'blockset_direct_configure:\n'
label_end = 'blockset_tail_blocks:\n'
assert gateway.count(label_start) == 1 and gateway.count(label_end) == 1
bridge = label_start + gateway.split(label_start, 1)[1].split(label_end, 1)[0]
header = ('.globl blockset_direct_configure\n'
          '.globl backstore_read\n.globl backstore_write\n'
          '.globl device_range_configure\n'
          '.globl device_region_map\n'
          '.globl volume_data_blocks\n'
          '.globl backing_region_count\n')
bridge = header + bridge

disk = '''        .globl dsk270_read_sector
dsk270_read_sector:
        aos     read_calls_v1316
        skipn   read_fault_v1316
        jrst    disk_good_v1319
        move    5,read_fault_v1316
        camn    5,read_calls_v1316
        jrst    disk_bad_v1319
disk_good_v1319:
        ; Physical DEVICE address must be 020 + backing block 1..8.
        move    4,read_calls_v1316
        addi    4,020
        came    2,4
        jrst    disk_bad_v1319
        ; Real gateway advances 0200 words after each sector.
        caie    4,021
        jrst    disk_last_v1319
        move    5,[012345670123]
        movem   5,(3)
disk_last_v1319:
        caie    4,030
        jrst    disk_ok_v1319
        move    5,[076543210765]
        movem   5,0177(3)
disk_ok_v1319:
        setz    1,
        popj    17,
disk_bad_v1319:
        seto    1,
        popj    17,
        .globl dsk270_write_sector
dsk270_write_sector:
        seto    1,
        popj    17,
        .globl drm236_read_block
drm236_read_block:
        seto    1,
        popj    17,
        .globl drm236_write_block
drm236_write_block:
        seto    1,
        popj    17,
'''
rest = before + bridge + disk + end + after
marker = '        .globl backstore_bitmap\n'
assert rest.count(marker) == 1
rest = rest.replace(marker, '''        .globl kconst_6_6
kconst_6_6: .word 6,,6
        .globl device_region_map
device_region_map: .word 0
        .globl volume_data_blocks
volume_data_blocks: .word 0
        .globl backing_region_count
backing_region_count: .word 0
''' + marker, 1)

# Configure production gateway before first production swap-in.
entry = '        movei   1,4\n        movem   1,proc_high_slot\n'
assert rest.count(entry) == 1
rest = rest.replace(entry, '''        movei   1,0
        movei   2,020
        movei   3,020
        pushj   17,device_range_configure
''' + entry, 1)

# One gateway invocation causes eight hardware sector reads, while the
# failed first-sector I/O must not attempt a second sector.
success = '        caie    1,1\n        jrst    fail18_v1313\n'
assert rest.count(success) == 1
rest = rest.replace(success, '        caie    1,010\n        jrst    fail18_v1313\n', 1)

for label, data in (('success', rest),
                    ('read-failure', rest.replace(
                        'read_fault_v1316: .word 0',
                        'read_fault_v1316: .word 1', 1)),
                    ('mid-read-failure', rest.replace(
                        'read_fault_v1316: .word 0',
                        'read_fault_v1316: .word 3', 1))):
    if label == 'mid-read-failure':
        expected = ('check_failed_event_v1317:\n'
                    '        move    1,event_calls_v1313\n'
                    '        caie    1,1                   ; fatal TERM path invoked once\n'
                    '        jrst    fail43_v1317\n'
                    '        move    1,read_calls_v1316\n'
                    '        caie    1,1\n')
        assert data.count(expected) == 1
        data = data.replace(expected, expected[:-len('        caie    1,1\n')] +
                            '        caie    1,3\n', 1)
    (work / ('fixture-' + label + '-v1319.s')).write_text(data)
assert rest.count('read_fault_v1316: .word 0') == 1
assert 'backstore_read:\nblockset_direct_tail_read:' in rest
assert 'dsk270_read_sector:\n' in rest

# Runtime negative: omitting the bridge's physical buffer increment
# must not pass the authentic whole-image payload verification.
bad = '        addi    010,0200\n'
assert rest.count(bad) == 1
broken_bridge = rest.replace(bad, '        addi    010,0\n', 1)
(work / 'unsafe-buffer-progress-v1319.s').write_text(broken_bridge)
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 500000 --timeout 40 \
    --workdir "$work/success" --name swap-device-v1319 \
    --expect __test_exit=0 --expect proc_timer_clock=0100 \
    --expect proc_swap_pressure_ticks=0 \
    --expect read_calls_v1316=010 --expect independent_run_v1316=1 \
    --expect event_calls_v1313=0 --expect mm_extent_count=1 \
    --expect backstore_blocks_used=0 --expect proc_swap_blocks_used=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1319.s" \
    "$work/fixture-success-v1319.s" > "$work/success.log" 2>&1 || {
        tail -55 "$work/success.log" >&2
        exit 1
    }

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 500000 --timeout 40 \
    --workdir "$work/read-failure" --name swap-device-fail-v1319 \
    --expect __test_exit=0 --expect proc_timer_clock=0100 \
    --expect read_calls_v1316=1 --expect independent_run_v1316=1 \
    --expect event_calls_v1313=1 --expect mm_extent_count=0 \
    --expect backstore_blocks_used=010 --expect proc_swap_blocks_used=010 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1319.s" \
    "$work/fixture-read-failure-v1319.s" \
    > "$work/read-failure.log" 2>&1 || {
        tail -55 "$work/read-failure.log" >&2
        exit 1
    }

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 500000 --timeout 40 \
    --workdir "$work/mid-read-failure" --name swap-device-midfail-v1319 \
    --expect __test_exit=0 --expect proc_timer_clock=0100 \
    --expect read_calls_v1316=3 --expect independent_run_v1316=1 \
    --expect event_calls_v1313=1 --expect mm_extent_count=0 \
    --expect backstore_blocks_used=010 --expect proc_swap_blocks_used=010 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1319.s" \
    "$work/fixture-mid-read-failure-v1319.s" \
    > "$work/mid-read-failure.log" 2>&1 || {
        tail -55 "$work/mid-read-failure.log" >&2
        exit 1
    }

if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 500000 --timeout 40 \
    --workdir "$work/unsafe-buffer-progress" --name swap-device-unsafe-v1319 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1319.s" \
    "$work/unsafe-buffer-progress-v1319.s" \
    > "$work/unsafe-buffer-progress.log" 2>&1; then
    echo 'v1319: unsafe gateway buffer progression accepted' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe-buffer-progress.log" || {
    echo 'v1319: invalid mutant did not reach a PDP-6 test assertion' >&2
    tail -35 "$work/unsafe-buffer-progress.log" >&2
    exit 1
}
echo 'v1319: production DEVICE gateway eight sectors, first/mid I/O '
echo 'v1319: rollback and corrupted gateway progression detection PASS'
