#!/bin/sh
# Booted F07 no-partner recovery: require five actual spinner sleeps.
# Only disposable test-user and diagnostic BRK code are changed.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1344_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-slot0-io-trace-v1344.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1344: prepared source-linked slot-0 wait and DEVICE trace at //p' \
    | tail -1)
test -n "$work" && test -f "$work/runner-v1344.sh"

python3 - "$work/runner-v1344.sh" "$work/runner-v1348.sh" <<'PY'
from pathlib import Path
import sys

src, dst = (Path(p) for p in sys.argv[1:])
text = src.read_text()
anchor = 'requester_source="$v1304_user_source"'
if text.count(anchor) != 1:
    raise ValueError('v1348 original disposable F07 user source moved')
text = text.replace(anchor, '''# The original v1343 assembly injections have already run.
# Modify only the disposable diagnostic BRK chain and F07 INIT copy.
python3 "$self/daimos-f07-spinner-progress-gate-v1348.py" \\
    "$work/source/system/kernel" "$v1304_user_source"
''' + anchor, 1)
dst.write_text(text)
PY
sh -n "$work/runner-v1348.sh"
echo "v1348: prepared source-authentic spinner witness guest at $work"
if [ "${V1348_PREPARE_ONLY:-0}" = 1 ]; then
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
echo 'v1348: boot real 256K PDP-6 with five-sleep independent witness'
set +e
sh "$work/runner-v1348.sh" > "$work/runner-v1348.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1348: full original guest acceptance not completed ($rc)" >&2
    tail -55 "$work/runner-v1348.log" >&2
    exit "$rc"
fi
echo "v1348: original strict full guest PASS, work=$work"
