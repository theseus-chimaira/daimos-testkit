#!/bin/sh
# Strict fault-specific 256K PDP-6 F07 swap-in bitmap refusal profile.
# The unchanged clean v1336/v1349 F07 baseline is a SEPARATE gate.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 "$self/daimos-k01-f07-faulted-verify-v1713.py" --self-test
sh "$self/daimos-k01-f07-deferred-native-v1713.sh"

output=$(V1494_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-refusal-fullguest-v1494.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1494: prepared disposable 256K guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1494.sh"

python3 - "$work/runner-v1494.sh" "$work/runner-v1713.sh" <<'PY'
from pathlib import Path
import sys

original, target = map(Path, sys.argv[1:])
text = original.read_text()
changes = (
    ('"$self/daimos-swap-independent-release-verify-v1336.py"',
     '"$self/daimos-k01-f07-faulted-verify-v1713.py"'),
    ('"$self/daimos-swap-refusal-fullguest-v1494.py"',
     '"$self/daimos-k01-f07-deferred-inject-v1713.py"'),
)
for old, new in changes:
    if text.count(old) != 1:
        raise AssertionError('v1713: expected independent source anchor: '
                             + old)
    text = text.replace(old, new, 1)
assert text.count('daimos-swap-owner-lifecycle-v1349.py') == 1
assert text.count('daimos-f07-swapstack-verify-v1207.py') == 1
assert text.count('daimos-f07-mm-peak-verify-v1203.py') == 1
target.write_text(text)
print('v1713: preserved original v1203/v1207/v1349 F07 acceptance; '
      'faulted v1336 is independently reclassified only in this profile')
PY
sh -n "$work/runner-v1713.sh"

if [ "${V1713_PREPARE_ONLY:-0}" = 1 ]; then
    echo 'v1713: PREPARED ONLY (not a physical guest PASS)'
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

echo 'v1713: boot original full 256K F07 workload with strict fault profile'
set +e
sh "$work/runner-v1713.sh" > "$work/runner-v1713.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/^v1075 work: //p' "$work/runner-v1713.log" | tail -1)
if [ -z "$guest" ] || [ ! -f "$guest/addresses" ] || \
    [ ! -f "$guest/simh.out" ]; then
    echo 'v1713: missing completed PDP-6 guest or physical evidence' >&2
    tail -60 "$work/runner-v1713.log" >&2
    exit 1
fi

# Run the fault-specific independent verifier again from the retained
# physical output, irrespective of the original runner exit status.
if ! python3 "$self/daimos-k01-f07-faulted-verify-v1713.py" \
    "$guest/addresses" "$guest/simh.out"; then
    echo 'v1713: physical injected-fault acceptance FAILED' >&2
    tail -60 "$work/runner-v1713.log" >&2
    exit 1
fi
if [ "$rc" -ne 0 ]; then
    echo 'v1713: other original F07 postflight checks FAILED' >&2
    tail -70 "$work/runner-v1713.log" >&2
    exit "$rc"
fi

echo "v1713: full physical fault-specific F07 PASS work=$work guest=$guest"
echo 'v1713: clean no-fault v1336/v1349 baseline remains a separate gate'
