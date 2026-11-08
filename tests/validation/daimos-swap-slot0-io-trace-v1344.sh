#!/bin/sh
# Full 256K PDP-6: preserve the v1343 guest; add read-only slot-0 I/O trace.
# No change to production KCORE, MM, swap, scheduler, or device drivers.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1343_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-independent-provider-release-v1343.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1343: prepared independent provider-release full guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1343.sh"

python3 - "$work/runner-v1343.sh" "$work/runner-v1344.sh" <<'PY'
from pathlib import Path
import sys

src, dest = (Path(p) for p in sys.argv[1:])
source = src.read_text()
old = 'daimos-simh-swap-live-sampler-v1342.py'
assert source.count(old) == 1, 'v1344 expected source-linked sampler'
source = source.replace(old,
                        'daimos-simh-swap-live-sampler-v1344.py', 1)
anchor = '''        printf 'f07t_next %s\\n' "$addr" >> "$work/addresses"'''
assert source.count(anchor) == 1, 'v1344 timer address anchor moved'
extra = '''
        # AC1 is the event pointer in the production proc_wait_boot loop.
        # PDP-6 ACs are directly addressable in 000000..000017.
        printf 'diag_ac1 000001\\n' >> "$work/addresses"
        printf 'diag_ac17 000017\\n' >> "$work/addresses"
        for name in drm236_active_request drm236_pending_request \\
                    storage_state proc_sched_kick; do
            addr=$(awk -v sym="$name" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || {
                echo "v1344: missing linked $name" >&2
                exit 1
            }
            printf '%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done'''
source = source.replace(anchor, anchor + extra, 1)
if __import__('os').environ.get('V1344_DIAG_STOP') == '1':
    stop = '--timeout "${V1306_TIMEOUT:-1810}")'
    assert source.count(stop) == 1, 'v1344 bounded sample anchor moved'
    source = source.replace(stop,
                            '--timeout "${V1306_TIMEOUT:-1810}" '
                            '--stop-after-samples)', 1)
dest.write_text(source)
PY
sh -n "$work/runner-v1344.sh"
echo "v1344: prepared source-linked slot-0 wait and DEVICE trace at $work"
if [ "${V1344_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_INTERVAL=${V1306_INTERVAL:-35}
export V1306_COUNT=${V1306_COUNT:-22}
export V1306_TIMEOUT=${V1306_TIMEOUT:-2700}
echo 'v1344: boot 256K PDP-6 with read-only slot-0 IO/event arguments'
set +e
sh "$work/runner-v1344.sh" > "$work/runner-v1344.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    if [ "${V1344_DIAG_STOP:-0}" = 1 ]; then
        # SIMH guest output may precede the runner's final path marker
        # without a newline (including a carriage-return separator).
        guest=$(sed -n 's/.*v1075 work: //p' \
            "$work/runner-v1344.log" | tail -1)
        test -n "$guest" && test -s "$guest/simh-sampler.log"
        grep -q 'intentionally stopped after diagnostic samples' \
            "$guest/simh.out.raw-v1306.log" || {
            echo 'v1344: missing bounded-sample completion' >&2
            exit "$rc"
        }
        echo "v1344: diagnostic-only samples complete, guest=$guest"
        echo 'v1344: NO full-guest acceptance, by design'
        exit 0
    fi
    echo "v1344: guest did not complete ($rc), acceptance remains OPEN" >&2
    tail -40 "$work/runner-v1344.log" >&2
    exit "$rc"
fi
echo "v1344: full guest completed strict checks, work=$work"
