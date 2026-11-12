#!/bin/sh
# Booted 256K PDP-6: two deliberately lost Type-236 DR_DONE publications
# are failed by the REAL 300-tick PI6 watchdog and propagated to swap-in.
# All instrumented source lives in the disposable guest copy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 "$self/daimos-backstore-watchdog-source-selftest-v1512.py" \
    "$DAIMOS_REPO/system/kernel"
python3 "$self/daimos-backstore-watchdog-verify-v1512.py" --self-test \
    > "$TMPDIR/daimos-backstore-watchdog-selftest-v1512.log"
tail -4 "$TMPDIR/daimos-backstore-watchdog-selftest-v1512.log"

output=$(V1511_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-device-error-physical-v1511.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1511: prepared mapped real DRM read-error guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1511.sh" && \
    test -f "$work/sampler-v1511.py"

python3 - "$work/runner-v1511.sh" "$work/runner-v1512.sh" \
    "$work/sampler-v1511.py" "$work/sampler-v1512.py" <<'PY'
from pathlib import Path
import sys

src, dst, previous, current = map(Path, sys.argv[1:])
runner = src.read_text()
anchor = ('python3 "$self/daimos-backstore-device-error-observer-v1511.py" \\\n'
          '    "$work/source/system/kernel"\n')
assert runner.count(anchor) == 1, 'v1512: actual Type-236 observer moved'
runner = runner.replace(anchor, anchor +
    'python3 "$self/daimos-backstore-watchdog-observer-v1512.py" \\\n'
    '    "$work/source/system/kernel"\n', 1)
anchor = 'if [ "${V1306_LIVE_SAMPLER:-0}" = 1 ]; then'
assert runner.count(anchor) == 1, 'v1512: mapped address stage moved'
addrs = '''        # v1512 source-linked actual lost PI2 and PI6 timeout witnesses.
        for name in lost_pi2 watchdog_errors; do
            sym="daimos_v1512_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || { echo "v1512: no $sym" >&2; exit 1; }
            printf 'v1512_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done
'''
runner = runner.replace(anchor, addrs + anchor, 1)
old = str(previous)
assert runner.count(old) == 1, 'v1512: sampler path drift'
dst.write_text(runner.replace(old, str(current), 1))

sampler = previous.read_text()
old = 'FIELDS = (\n'
assert sampler.count(old) == 1
sampler = sampler.replace(old,
    old + "    'v1512_lost_pi2',\n    'v1512_watchdog_errors',\n", 1)
old = "if __name__ == '__main__':\n"
assert sampler.count(old) == 1
sampler = sampler.replace(old, '''# v1512: lost Type-236 completion vs real PI6 watchdog accounting.
_v1511_summary_v1512 = summary
def summary(number, pc, values):
    return _v1511_summary_v1512(number, pc, values) + (
        ' lost_pi2=%d watchdog_errors=%d' % (
            values['v1512_lost_pi2'], values['v1512_watchdog_errors']))

''' + old, 1)
# Additional actual watchdog waits need slightly more post-fault time.
# The real independent PID011 also wakes after a long timer delay.
old = 'args.count = max(args.count, taken + 12)'
assert sampler.count(old) == 1
sampler = sampler.replace(old, 'args.count = max(args.count, taken + 15)', 1)
current.write_text(sampler)
PY
sh -n "$work/runner-v1512.sh"
python3 -m py_compile "$work/sampler-v1512.py"
echo "v1512: prepared lost-completion physical watchdog guest at $work"
if [ "${V1512_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_TIMEOUT=${V1306_TIMEOUT:-2000}
unset V1344_DIAG_STOP
echo 'v1512: booting 256K PDP-6 lost PI2 completion / real PI6 timeout'
set +e
sh "$work/runner-v1512.sh" > "$work/runner-v1512.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1512.log" | \
    tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh-sampler.log" ] || \
    [ ! -s "$guest/simh.out" ]; then
    echo 'v1512: missing physical watchdog evidence' >&2
    tail -65 "$work/runner-v1512.log" >&2
    exit 1
fi
grep -q 'intentionally stopped after diagnostic samples' \
    "$guest/simh.out.raw-v1306.log" || {
        echo 'v1512: incomplete bounded sample horizon' >&2
        tail -45 "$guest/simh-sampler.log" >&2
        exit 1
    }
python3 "$self/daimos-backstore-watchdog-verify-v1512.py" \
    "$guest/simh-sampler.log" "$guest/simh.out"
echo "v1512: diagnostic runner_rc=$rc (normal F07 HALT not expected)"
echo "v1512: evidence work=$work guest=$guest"
