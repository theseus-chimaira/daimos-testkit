#!/bin/sh
# Booted PDP-6: real DSK PI5 driver failure -> BACKSTORE read error,
# rollback/TERM and healthy independent swapped restore, no kernel edits.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 "$self/daimos-backstore-device-error-source-selftest-v1511.py" \
    "$DAIMOS_REPO/system/kernel"
python3 "$self/daimos-backstore-device-error-verify-v1511.py" --self-test \
    > "$TMPDIR/daimos-device-error-v1511-selftest.log"
tail -5 "$TMPDIR/daimos-device-error-v1511-selftest.log"

output=$(V1510_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-swapped-physical-v1510.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1510: prepared real healthy swapped-contender guest at //p' | \
    tail -1)
test -n "$work" && test -f "$work/runner-v1510.sh" && \
    test -f "$work/sampler-v1510.py"

python3 - "$work/runner-v1510.sh" "$work/runner-v1511.sh" \
    "$work/sampler-v1510.py" "$work/sampler-v1511.py" <<'PY'
from pathlib import Path
import sys

src, dst, previous, current = map(Path, sys.argv[1:])
runner = src.read_text()
old = ('python3 "$self/daimos-backstore-swapped-observer-v1510.py" \\\n'
       '    "$work/source/system/kernel"\n')
assert runner.count(old) == 1, 'v1511 changed physical injector stage'
runner = runner.replace(old, old +
    'python3 "$self/daimos-backstore-device-error-observer-v1511.py" \\\n'
    '    "$work/source/system/kernel"\n', 1)
anchor = 'if [ "${V1306_LIVE_SAMPLER:-0}" = 1 ]; then'
assert runner.count(anchor) == 1, 'v1511 mapped address stage moved'
addresses = '''        # v1511: exact linked device-error counter and real DSK0
        # controller accounting word, no synthetic status values.
        python3 - "$build/kcore.map" "$work/addresses" <<'PYV1511'
from pathlib import Path
import sys
values = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2 and all(c in '01234567' for c in parts[1]):
        values[parts[0]] = int(parts[1], 8)
required = ('daimos_v1511_device_errors', 'mfsdev_storage_errors')
assert all(name in values for name in required), 'v1511 DSK map incomplete'
with Path(sys.argv[2]).open('a') as out:
    out.write('v1511_device_errors %06o\\n' % values[required[0]])
    out.write('v1511_dsk_errors %06o\\n' % (values[required[1]] + 2))
PYV1511
'''
runner = runner.replace(anchor, addresses + anchor, 1)
old = str(previous)
assert runner.count(old) == 1, 'v1511 sampler path moved'
dst.write_text(runner.replace(old, str(current), 1))

sampler = previous.read_text()
anchor = 'FIELDS = (\n'
assert sampler.count(anchor) == 1
sampler = sampler.replace(anchor,
    anchor + "    'v1511_device_errors',\n    'v1511_dsk_errors',\n", 1)
anchor = "if __name__ == '__main__':\n"
assert sampler.count(anchor) == 1
sampler = sampler.replace(anchor, '''# v1511: separate true DSK PI5 error events from checked free refusals.
_v1510_summary_v1511 = summary
def summary(number, pc, values):
    return _v1510_summary_v1511(number, pc, values) + (
        ' device_errors=%d dsk_errors=%d' % (
            values['v1511_device_errors'], values['v1511_dsk_errors']))

''' + anchor, 1)
current.write_text(sampler)
PY
sh -n "$work/runner-v1511.sh"
python3 -m py_compile "$work/sampler-v1511.py"
echo "v1511: prepared mapped real DSK read-error guest at $work"
if [ "${V1511_PREPARE_ONLY:-0}" = 1 ]; then
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
echo 'v1511: booting 256K PDP-6 with two selected real PI5 DSK errors'
set +e
sh "$work/runner-v1511.sh" > "$work/runner-v1511.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1511.log" | \
    tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh-sampler.log" ] || \
    [ ! -s "$guest/simh.out" ]; then
    echo 'v1511: missing real DSK physical diagnostic evidence' >&2
    tail -65 "$work/runner-v1511.log" >&2
    exit 1
fi
grep -q 'intentionally stopped after diagnostic samples' \
    "$guest/simh.out.raw-v1306.log" || {
        echo 'v1511: incomplete physical sample horizon' >&2
        tail -40 "$guest/simh-sampler.log" >&2
        exit 1
    }
python3 "$self/daimos-backstore-device-error-verify-v1511.py" \
    "$guest/simh-sampler.log" "$guest/simh.out"
echo "v1511: diagnostic runner_rc=$rc (not all-children HALT)"
echo "v1511: evidence work=$work guest=$guest"
