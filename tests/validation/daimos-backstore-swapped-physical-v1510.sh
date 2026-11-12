#!/bin/sh
# Full 256K KCC PDP-6: slot 011 restores and executes after another
# slot's checked BACKSTORE release remains permanently unavailable.
# Every code change is confined to a disposable guest copy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$self/daimos-backstore-swapped-source-selftest-v1510.py"
python3 "$self/daimos-backstore-swapped-verify-v1510.py" --self-test \
    > "$TMPDIR/daimos-backstore-swapped-selftest-v1510.log"
tail -4 "$TMPDIR/daimos-backstore-swapped-selftest-v1510.log"

output=$(V1509_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-bystander-physical-v1509.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1509: prepared persistent fault and PID5 progress guest at //p' | \
    tail -1)
test -n "$work" && test -f "$work/runner-v1509.sh" && \
    test -f "$work/sampler-v1509.py"

python3 - "$work/runner-v1509.sh" "$work/runner-v1510.sh" \
    "$work/sampler-v1509.py" "$work/sampler-v1510.py" <<'PY'
from pathlib import Path
import sys

src, dst, old_sampler, new_sampler = map(Path, sys.argv[1:])
runner = src.read_text()
anchor = ('python3 "$self/daimos-backstore-bystander-user-v1509.py" \\\n'
          '    "$v1304_user_source"\n')
assert runner.count(anchor) == 1, 'v1510: F07 source stage moved'
runner = runner.replace(anchor, anchor +
    'python3 "$self/daimos-backstore-swapped-user-v1510.py" \\\n'
    '    "$v1304_user_source"\n', 1)
anchor = ('python3 "$self/daimos-backstore-persistent-physical-v1508.py" \\\n'
          '    "$work/source/system/kernel"\n')
assert runner.count(anchor) == 1, 'v1510: original fault stage moved'
runner = runner.replace(anchor, anchor +
    'python3 "$self/daimos-backstore-swapped-observer-v1510.py" \\\n'
    '    "$work/source/system/kernel"\n', 1)

anchor = 'if [ "${V1306_LIVE_SAMPLER:-0}" = 1 ]; then'
assert runner.count(anchor) == 1, 'v1510: mapped address stage moved'
address = r'''        for name in restore_count exchange_count sleep_count; do
            sym="daimos_v1510_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \
                "$build/kcore.map")
            test -n "$addr" || { echo "v1510: missing $sym" >&2; exit 1; }
            printf 'v1510_%s %s\n' "$name" "$addr" >> "$work/addresses"
        done
'''
runner = runner.replace(anchor, address + anchor, 1)
old = str(old_sampler)
assert runner.count(old) == 1, 'v1510: sampler path changed'
runner = runner.replace(old, str(new_sampler), 1)
dst.write_text(runner)

sampler = old_sampler.read_text()
anchor = 'FIELDS = (\n'
assert sampler.count(anchor) == 1
sampler = sampler.replace(anchor,
    anchor + ''.join('    %r,\n' % name for name in (
        'v1510_restore_count', 'v1510_exchange_count',
        'v1510_sleep_count')), 1)
anchor = "if __name__ == '__main__':\n"
assert sampler.count(anchor) == 1
sampler = sampler.replace(anchor, '''# v1510: actual checked restore, exchange and user SLEEP witnesses.
_v1509_summary_v1510 = summary
def summary(number, pc, values):
    return _v1509_summary_v1510(number, pc, values) + (
        ' contender_restore=%d contender_exchange=%d contender_sleep=%d' % (
            values['v1510_restore_count'], values['v1510_exchange_count'],
            values['v1510_sleep_count']))

''' + anchor, 1)
# The original v1509 adaptive horizon covers 5 fault-on snapshots;
# this candidate first wakes after the 0120000-tick timer. Allow
# further real samples for a successful restore and user dispatch.
old = 'args.count = max(args.count, taken + 5)'
assert sampler.count(old) == 1
sampler = sampler.replace(old, 'args.count = max(args.count, taken + 12)', 1)
new_sampler.write_text(sampler)
PY
sh -n "$work/runner-v1510.sh"
python3 -m py_compile "$work/sampler-v1510.py"
echo "v1510: prepared real healthy swapped-contender guest at $work"
if [ "${V1510_PREPARE_ONLY:-0}" = 1 ]; then
    exit 0
fi

export KEEP_TEST=1 V1304_PREPARE_ONLY=0
export V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1
export V1205_TEST_CONCURRENT=1 V1206_TEST_COMBINED=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
export V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=${V1306_INTERVAL:-30}
export V1306_COUNT=${V1306_COUNT:-22}
export V1306_TIMEOUT=${V1306_TIMEOUT:-1800}
unset V1344_DIAG_STOP
echo 'v1510: booting disposable 256K PDP-6 with delayed swapped PID011'
set +e
sh "$work/runner-v1510.sh" > "$work/runner-v1510.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1510.log" | \
    tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh-sampler.log" ] || \
    [ ! -s "$guest/simh.out" ]; then
    echo 'v1510: missing physical swapped-contender evidence' >&2
    tail -70 "$work/runner-v1510.log" >&2
    exit 1
fi
grep -q 'intentionally stopped after diagnostic samples' \
    "$guest/simh.out.raw-v1306.log" || {
        echo 'v1510: incomplete diagnostic sampling' >&2
        tail -45 "$guest/simh-sampler.log" >&2
        exit 1
    }
python3 "$self/daimos-backstore-swapped-verify-v1510.py" \
    "$guest/simh-sampler.log" "$guest/simh.out"
echo "v1510: diagnostic runner_rc=$rc (normal F07 HALT not expected)"
echo "v1510: evidence work=$work guest=$guest"
