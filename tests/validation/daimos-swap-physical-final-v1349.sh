#!/bin/sh
# Strict 256K PDP-6 F07: real owner lifecycle, held provider and swap HALT.
# Preserve authoritative v1336 final and add independent live-phase check.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1348_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-spinner-witness-v1348.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1348: prepared source-authentic spinner witness guest at //p' \
    | tail -1)
test -n "$work" && test -f "$work/runner-v1348.sh"

python3 - "$work/runner-v1348.sh" "$work/runner-v1349.sh" <<'PY'
from pathlib import Path
import sys

src, dest = (Path(p) for p in sys.argv[1:])
source = src.read_text()
old = '''    cat "$work/f07c-v1206.txt"
fi'''
if source.count(old) != 1 or \
        source.count('daimos-swap-independent-release-verify-v1336.py') != 1:
    raise ValueError('v1349 source-authentic final owner verifier moved')
new = '''    cat "$work/f07c-v1206.txt"
    # Additional independent source-linked lifetime verification;
    # never replace or relax v1336's final physical owner audit.
    python3 "$self/daimos-swap-owner-lifecycle-v1349.py" \\
        "$work/addresses" "$work/simh.out" "$work/simh-sampler.log" \\
        > "$work/f07owner-v1349.txt"
    cat "$work/f07owner-v1349.txt"
fi'''
source = source.replace(old, new, 1)
old = '''        cp "$work/f07c-v1206.txt" "$e/f07c-v1206.txt"'''
if source.count(old) != 1:
    raise ValueError('v1349 original evidence copy moved')
source = source.replace(old, old + '''
        cp "$work/f07owner-v1349.txt" "$e/f07owner-v1349.txt"''', 1)
old = '''        (cd "$e" && sha256sum f07c-v1206.txt >> evidence-sha256.txt)'''
if source.count(old) != 1:
    raise ValueError('v1349 original evidence manifest moved')
source = source.replace(old, old + '''
        (cd "$e" && sha256sum f07owner-v1349.txt >> evidence-sha256.txt)''', 1)
dest.write_text(source)
PY
sh -n "$work/runner-v1349.sh"
echo "v1349: prepared split-phase owner and original strict F07 at $work"
if [ "${V1349_PREPARE_ONLY:-0}" = 1 ]; then
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
echo 'v1349: boot strict physical 256K PDP-6 with phase-correct MM owner checks'
set +e
sh "$work/runner-v1349.sh" > "$work/runner-v1349.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1349: original F07 full-guest postflight FAILED ($rc)" >&2
    tail -55 "$work/runner-v1349.log" >&2
    exit "$rc"
fi
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1349.log" | tail -1)
test -n "$guest" && test -f "$guest/addresses"
python3 "$self/daimos-swap-no-partner-physical-v1303.py" \
    "$guest/addresses" "$guest/simh.out"
echo "v1349: ORIGINAL F07 + real physical no-partner full guest PASS, work=$work guest=$guest"
