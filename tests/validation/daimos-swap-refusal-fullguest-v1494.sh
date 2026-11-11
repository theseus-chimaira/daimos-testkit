#!/bin/sh
# v1494: injected real 256K PDP-6 F07 swap-in/TERM/finalizer bitmap refusal.
# Mutates only the copied guest kernel, never the checked-out DAIMOS source.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 "$self/daimos-swap-refusal-verify-v1494.py" --self-test
output=$(V1349_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-physical-final-v1349.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1349: prepared split-phase owner and original strict F07 at //p' \
    | tail -1)
test -n "$work" && test -f "$work/runner-v1349.sh"

python3 - "$work/runner-v1349.sh" "$work/runner-v1494.sh" <<'PY'
from pathlib import Path
import sys

original, destination = map(Path, sys.argv[1:])
text = original.read_text()
anchor = 'requester_source="$v1304_user_source"'
if text.count(anchor) != 1:
    raise AssertionError('v1494 disposable F07 kernel injection site moved')
text = text.replace(anchor, '''python3 "$self/daimos-swap-refusal-fullguest-v1494.py" \\
    "$work/source/system/kernel"
''' + anchor, 1)
anchor = '''        printf 'diag_ac17 000017\\n' >> "$work/addresses"'''
if text.count(anchor) != 1:
    raise AssertionError('v1494 source-map address site moved')
extra = '''
        for name in armed faults free_calls terms repairs errors slot \\
                    first blocks bitmap_addr bitmap_saved; do
            sym="daimos_v1494_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || { echo "v1494: missing $sym" >&2; exit 1; }
            printf 'v1494_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done'''
text = text.replace(anchor, anchor + extra, 1)
destination.write_text(text)
PY
sh -n "$work/runner-v1494.sh"
echo "v1494: prepared disposable 256K guest at $work"
if [ "${V1494_PREPARE_ONLY:-0}" = 1 ]; then
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
echo 'v1494: starting real 256K KCC F07 bitmap-refusal guest'
set +e
sh "$work/runner-v1494.sh" > "$work/runner-v1494.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1494.log" | tail -1)
if [ -n "$guest" ] && [ -f "$guest/addresses" ] && \
    [ -f "$guest/simh.out" ]; then
    if python3 "$self/daimos-swap-refusal-verify-v1494.py" \
        "$guest/addresses" "$guest/simh.out"; then
        echo 'v1494: real physical swap-in/TERM/PREVM/finalizer gate PASS'
    else
        echo 'v1494: physical evidence INCOMPLETE or FAILED' >&2
        exit 1
    fi
else
    echo 'v1494: no complete guest/evidence paths found' >&2
    tail -60 "$work/runner-v1494.log" >&2
    exit 1
fi
if [ "$rc" -ne 0 ]; then
    echo 'v1494: faulted guest did not pass all ORIGINAL F07 postflight gates' >&2
    tail -50 "$work/runner-v1494.log" >&2
    exit "$rc"
fi
echo "v1494: strict original F07 postflight also PASS work=$work guest=$guest"
