#!/bin/sh
# Derived from the strict physical F07 v1495 diagnostic, with two-event
# owner snapshots and exact branch witnesses. No production change.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1495_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-refusal-diagnostic-v1495.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1495: prepared diagnostic full-guest runner at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1495.sh"

python3 - "$work/runner-v1495.sh" "$work/runner-v1499.sh" <<'PY'
from pathlib import Path
import sys

src, out = map(Path, sys.argv[1:])
text = src.read_text()
anchor = 'daimos-swap-refusal-instrument-v1495.py'
if text.count(anchor) != 1:
    raise AssertionError('v1499 original guest injection moved')
text = text.replace(anchor, 'daimos-backstore-term-branch-v1499.py', 1)
anchor = '''            printf 'v1495_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done'''
if text.count(anchor) != 1:
    raise AssertionError('v1499 address-map insertion point moved')
extra = '''
        for name in events active overflow foreign deferred busy finish \\
                    prevm_refused close_refused; do
            sym="daimos_v1499_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || { echo "v1499: no $sym" >&2; exit 1; }
            printf 'v1499_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done
        for name in pre_meta pre_vm pre_sched pre_pc pre_fdctl \\
                    pre_finalize event_result post_meta post_vm \\
                    post_sched post_fdctl post_finalize; do
            sym="daimos_v1499_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || { echo "v1499: no $sym" >&2; exit 1; }
            for i in 0 1; do
                printf 'v1499_%s_%s %06o\\n' "$name" "$i" \\
                    "$((addr + i))" >> "$work/addresses"
            done
        done'''
text = text.replace(anchor, anchor + extra, 1)
out.write_text(text)
PY
sh -n "$work/runner-v1499.sh"
echo "v1499: prepared full-guest branch diagnostic at $work"
if [ "${V1499_PREPARE_ONLY:-0}" = 1 ]; then
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
echo 'v1499: booting disposable 256K KCC PDP-6 owner-branch trace'
set +e
sh "$work/runner-v1499.sh" > "$work/runner-v1499.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1499.log" | tail -1)
if [ -n "$guest" ] && [ -f "$guest/addresses" ] && \
    [ -f "$guest/simh.out" ]; then
    python3 "$self/daimos-backstore-term-branch-report-v1499.py" \
        "$guest/addresses" "$guest/simh.out"
else
    echo 'v1499: missing completed mapped physical evidence' >&2
    tail -48 "$work/runner-v1499.log" >&2
    exit 1
fi
if [ "$rc" -ne 0 ]; then
    echo 'v1499: existing F07 strict postflight FAILED (diagnostic only)' >&2
    tail -20 "$work/runner-v1499.log" >&2
    exit "$rc"
fi
echo "v1499: normal F07 postflight PASS work=$work guest=$guest"
