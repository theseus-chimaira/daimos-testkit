#!/bin/sh
# Source-authentic F07 guest with Ctrl-E-safe output and timer frontier.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1338_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-independent-trace-v1338.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1338: prepared exact-source MM owner query diagnostics at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1338.sh"

python3 - "$work/runner-v1338.sh" "$work/runner-v1340.sh" <<'PY'
from pathlib import Path
import sys

src, dest = (Path(p) for p in sys.argv[1:])
source = src.read_text()
original = 'daimos-simh-swap-live-sampler-v1338.py'
assert source.count(original) == 1
source = source.replace(original,
                        'daimos-simh-swap-live-sampler-v1340.py', 1)
anchor = '''        done
    fi
    if [ "$f07_concurrent" = 1 ]; then'''
assert source.count(anchor) == 1
extra = '''        done
        addr=$(awk '$1 == "proc_timer_next" {print $2}' \\
            "$build/kcore.map")
        test -n "$addr" || { echo 'v1340: missing timer frontier' >&2; exit 1; }
        printf 'f07t_next %s\\n' "$addr" >> "$work/addresses"
    fi
    if [ "$f07_concurrent" = 1 ]; then'''
source = source.replace(anchor, extra, 1)
dest.write_text(source)
PY
sh -n "$work/runner-v1340.sh"
echo "v1340: prepared Ctrl-E-safe F07 with timer frontier at $work"
if [ "${V1340_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_INTERVAL=${V1306_INTERVAL:-45}
export V1306_COUNT=${V1306_COUNT:-24}
export V1306_TIMEOUT=${V1306_TIMEOUT:-3610}
echo 'v1340: boot physical 256K PDP-6 with preserved Ctrl-E guest output'
set +e
sh "$work/runner-v1340.sh" > "$work/runner-v1340.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1340: guest failed ($rc), acceptance still OPEN" >&2
    tail -50 "$work/runner-v1340.log" >&2
    exit "$rc"
fi
echo "v1340: runner and original strict guest checks completed, work=$work"
