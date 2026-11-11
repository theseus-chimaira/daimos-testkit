#!/bin/sh
# Full-guest v1494 extension: distinguish real TERM event, stack witness
# and PREVM retry-state failure. Leave baseline F07 assertions unchanged.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1494_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-refusal-fullguest-v1494.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1494: prepared disposable 256K guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1494.sh"

python3 - "$work/runner-v1494.sh" "$work/runner-v1495.sh" <<'PY'
from pathlib import Path
import sys

source, output = map(Path, sys.argv[1:])
text = source.read_text()
old = 'daimos-swap-refusal-fullguest-v1494.py'
if text.count(old) != 1:
    raise AssertionError('v1495: parent injection no longer unique')
text = text.replace(old, 'daimos-swap-refusal-instrument-v1495.py', 1)
old = '''            printf 'v1494_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done'''
if text.count(old) != 1:
    raise AssertionError('v1495: missing mapped diagnostic insertion site')
extra = '''
        for name in failed_entry service_slot event_returned \\
                    witness_enter witness_slot witness_top witness_below \\
                    term_unlock_error term_mark_error retry_unlock_error \\
                    retry_mark_error retry_descriptor retry_marker; do
            sym="daimos_v1495_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || {
                echo "v1495: missing mapped diagnostic $sym" >&2
                exit 1
            }
            printf 'v1495_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done'''
text = text.replace(old, old + extra, 1)
output.write_text(text)
PY
sh -n "$work/runner-v1495.sh"
echo "v1495: prepared diagnostic full-guest runner at $work"
if [ "${V1495_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_INTERVAL=${V1306_INTERVAL:-40}
export V1306_COUNT=${V1306_COUNT:-18}
export V1306_TIMEOUT=${V1306_TIMEOUT:-2700}
unset V1344_DIAG_STOP
echo 'v1495: executing real 256K PDP-6 with independent failure witnesses'
set +e
sh "$work/runner-v1495.sh" > "$work/runner-v1495.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1495.log" | tail -1)
if [ -n "$guest" ] && [ -f "$guest/addresses" ] && \
    [ -f "$guest/simh.out" ]; then
    python3 "$self/daimos-swap-refusal-report-v1495.py" \
        "$guest/addresses" "$guest/simh.out"
else
    echo 'v1495: missing physical diagnostic evidence' >&2
    tail -50 "$work/runner-v1495.log" >&2
    exit 1
fi
if [ "$rc" -ne 0 ]; then
    echo 'v1495: original F07 acceptance FAILED; diagnostic only' >&2
    tail -28 "$work/runner-v1495.log" >&2
    exit "$rc"
fi
echo "v1495: original F07 postflight PASS work=$work guest=$guest"
