#!/bin/sh
# Full 256K guest with corrected disposable-only held-provider release.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1342_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-independent-trace-v1342.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1342: prepared Ctrl-E-safe F07 with timer frontier at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1342.sh"

python3 - "$work/runner-v1342.sh" "$work/runner-v1343.sh" <<'PY'
from pathlib import Path
import sys

src, dest = (Path(p) for p in sys.argv[1:])
source = src.read_text()
anchor = '''        python3 "$self/daimos-f07-releaser-trace-v1338.py" \\
            "$work/source/system/kernel"'''
if source.count(anchor) != 1:
    raise ValueError('v1343 original independent releaser moved')
source = source.replace(anchor, anchor + '''
        python3 "$self/daimos-f07-independent-provider-release-v1343.py" \\
            "$work/source/system/kernel"''', 1)
dest.write_text(source)
PY
sh -n "$work/runner-v1343.sh"
echo "v1343: prepared independent provider-release full guest at $work"
if [ "${V1343_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_COUNT=${V1306_COUNT:-30}
export V1306_TIMEOUT=${V1306_TIMEOUT:-3610}
echo 'v1343: boot physical 256K PDP-6 with genuine provider owner release'
set +e
sh "$work/runner-v1343.sh" > "$work/runner-v1343.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1343: full guest failed ($rc), acceptance still OPEN" >&2
    tail -45 "$work/runner-v1343.log" >&2
    exit "$rc"
fi
echo "v1343: original strict full-guest checks completed, work=$work"
