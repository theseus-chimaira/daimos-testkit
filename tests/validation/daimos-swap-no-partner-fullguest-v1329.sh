#!/bin/sh
# Boot genuine PDP-6 MM-pin no-partner fixture with prompt-clean sampling.
# The already versioned v1326 test controls real mm_pin/mm_unpin only.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

output=$(V1326_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-no-partner-fullguest-v1326.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | \
    sed -n 's/^v1326: prepared disposable real-MM-pin guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1304.sh"

python3 - "$work/runner-v1304.sh" "$work/runner-v1329.sh" <<'PY'
from pathlib import Path
import sys
original, destination = (Path(p) for p in sys.argv[1:])
source = original.read_text()
old = 'daimos-simh-swap-live-sampler-v1324.py'
assert source.count(old) == 1, 'v1329 PTY sampler hook moved'
source = source.replace(old, 'daimos-simh-swap-live-sampler-v1326.py', 1)
assert 'daimos-f07-mm-pin-residents-v1326.py' in source
assert 'daimos-f07-mm-pin-verify-v1326.py' in source
destination.write_text(source)
PY
sh -n "$work/runner-v1329.sh"
echo "v1329: prepared source-authentic real-MM-pin guest at $work"
if [ "${V1329_PREPARE_ONLY:-0}" = 1 ]; then
    exit 0
fi

export KEEP_TEST=1 V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1
export V1205_TEST_CONCURRENT=1 V1206_TEST_COMBINED=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
export V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=${V1306_INTERVAL:-90}
export V1306_COUNT=${V1306_COUNT:-14}
export V1306_TIMEOUT=${V1306_TIMEOUT:-1810}
echo 'v1329: boot genuine 256K PDP-6 with real MM resident pinning'
set +e
sh "$work/runner-v1329.sh" > "$work/runner-v1329.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1329: guest failed ($rc); no liveness acceptance" >&2
    tail -55 "$work/runner-v1329.log" >&2
    exit "$rc"
fi
guest=$(sed -n 's/^v1075 work: //p' "$work/runner-v1329.log" | tail -1)
test -n "$guest" && test -f "$guest/addresses"
set +e
python3 "$self/daimos-swap-no-partner-physical-v1303.py" \
    "$guest/addresses" "$guest/simh.out"
classified=$?
set -e
case "$classified" in
    0) echo 'v1329: real-MM no-partner physical guest PASS' ;;
    3) echo 'v1329: full guest PASS, no-partner NOT EXERCISED' ;;
    *) echo "v1329: evidence invalid ($classified)" >&2
       exit "$classified" ;;
esac
echo "v1329: work=$work guest=$guest"
