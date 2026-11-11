#!/bin/sh
# Source-authentic 256K PDP-6: observe owning TERM consumption after
# a controlled one-bit BACKSTORE corruption and eventual repair.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1499_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-term-branch-v1499.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1499: prepared full-guest branch diagnostic at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1499.sh"

python3 - "$work/runner-v1499.sh" "$work/runner-v1504.sh" <<'PY'
from pathlib import Path
import sys

src, dst = map(Path, sys.argv[1:])
text = src.read_text()
old = 'daimos-backstore-term-branch-v1499.py'
if text.count(old) != 1:
    raise AssertionError('v1504: expected one source injector')
text = text.replace(old, 'daimos-backstore-owner-return-v1504.py', 1)
old = '''        for name in drm236_active_request drm236_pending_request \\
                    storage_state proc_sched_kick; do'''
if text.count(old) != 1:
    raise AssertionError('v1504: final mapped-witness insertion moved')
extra = '''        for name in armed_fdctl armed_sched armed_pc \\
                    owner_term_count owner_slot owner_fdctl_before \\
                    owner_backing_before owner_commit_count \\
                    owner_fdctl_after private_fatal_count private_status \\
                    finish_count finish_status zombie_count; do
            sym="daimos_v1504_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || { echo "v1504: no $sym" >&2; exit 1; }
            printf 'v1504_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done
        for name in def_count def_kind def_prior; do
            sym="daimos_v1504_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || { echo "v1504: no $sym" >&2; exit 1; }
            for i in $(seq 0 63); do
                printf 'v1504_%s_%02o %06o\\n' "$name" "$i" \\
                    "$((addr + i))" >> "$work/addresses"
            done
        done
'''
text = text.replace(old, extra + old, 1)
dst.write_text(text)
PY
sh -n "$work/runner-v1504.sh"
echo "v1504: prepared 256K physical owner-return runner at $work"
if [ "${V1504_PREPARE_ONLY:-0}" = 1 ]; then
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
echo 'v1504: booting disposable 256K PDP-6 owner-return trace'
set +e
sh "$work/runner-v1504.sh" > "$work/runner-v1504.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1504.log" | tail -1)
if [ -z "$guest" ] || [ ! -f "$guest/addresses" ] || \
    [ ! -f "$guest/simh.out" ]; then
    echo 'v1504: no complete mapped physical evidence' >&2
    tail -50 "$work/runner-v1504.log" >&2
    exit 1
fi
python3 "$self/daimos-backstore-owner-return-report-v1504.py" \
    "$guest/addresses" "$guest/simh.out"
python3 "$self/daimos-backstore-owner-return-verify-v1504.py" \
    "$guest/addresses" "$guest/simh.out"
echo "v1504: guest postflight rc=$rc (normal v1336 rejects injected failures)"
echo "v1504: evidence work=$work guest=$guest"
