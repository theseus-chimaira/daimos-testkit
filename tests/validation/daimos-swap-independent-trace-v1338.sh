#!/bin/sh
# Diagnostic-only F07 guest: observe independent releaser's query path.
# Original production kernel sources remain untouched.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1336_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-independent-release-v1336.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1336: prepared independent-resident real-MM guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1336.sh"

python3 - "$work/runner-v1336.sh" "$work/runner-v1338.sh" <<'PY'
from pathlib import Path
import sys

old, new = (Path(p) for p in sys.argv[1:])
source = old.read_text()
injector = '''        python3 "$self/daimos-f07-independent-releaser-v1336.py" \\
            "$work/source/system/kernel"'''
assert source.count(injector) == 1, 'v1338 base fixture changed'
source = source.replace(injector, injector + '''
        python3 "$self/daimos-f07-releaser-trace-v1338.py" \\
            "$work/source/system/kernel"''', 1)
old_sampler = 'daimos-simh-swap-live-sampler-v1332.py'
assert source.count(old_sampler) == 1
source = source.replace(old_sampler,
                        'daimos-simh-swap-live-sampler-v1338.py', 1)
anchor = '''        done
    fi
    if [ "$f07_concurrent" = 1 ]; then'''
assert source.count(anchor) == 1, 'v1338 source-linked map block changed'
extra = '''        done
        for name in calls last release_calls; do
            sym="daimos_f07q_${name}_v1338"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \\
                "$build/kcore.map")
            test -n "$addr" || {
                echo "v1338: missing $sym" >&2
                exit 1
            }
            printf 'f07q_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done
    fi
    if [ "$f07_concurrent" = 1 ]; then'''
source = source.replace(anchor, extra, 1)
new.write_text(source)
PY
sh -n "$work/runner-v1338.sh"
echo "v1338: prepared exact-source MM owner query diagnostics at $work"
if [ "${V1338_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_INTERVAL=${V1306_INTERVAL:-60}
export V1306_COUNT=${V1306_COUNT:-20}
export V1306_TIMEOUT=${V1306_TIMEOUT:-3610}
echo 'v1338: boot genuine 256K PDP-6 with live source-linked releaser diagnostics'
set +e
sh "$work/runner-v1338.sh" > "$work/runner-v1338.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1338: diagnostic guest failed ($rc); no acceptance" >&2
    tail -50 "$work/runner-v1338.log" >&2
    exit "$rc"
fi
echo "v1338: generated runner completed; separate strict guest acceptance required"
echo "v1338: work=$work"
