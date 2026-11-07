#!/bin/sh
# Full 256K F07 test: 24K process images and six genuine 8K MM extents.
# Does not invent pressure errors; unexercised no-partner remains OPEN.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export KEEP_TEST=1 V1304_PREPARE_ONLY=1
output=$(sh "$self/daimos-swap-no-partner-fullguest-v1304.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n 's/^v1304 fixture: //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1304.sh"

python3 - "$work/runner-v1304.sh" "$self" <<'PY'
from pathlib import Path
import sys

runner, self = (Path(p) for p in sys.argv[1:])
source = runner.read_text()
guard = '''if [ "$f07_swapslots" = 1 ] && {
    [ "$f07_concurrent" != 1 ] || [ "$f07_peak" != 1 ] ||
    [ "$f07_combined" != 0 ] || [ "$f07_high" != 0 ]; }; then
    echo 'v1207: requires v1203/v1205 real processes without synthetic pressure' >&2
    exit 2
fi'''
replacement = '''# v1321 only: distinct disposable guest with six genuinely allocated
# MM_TYPE_KERNEL_DYNAMIC extents, on top of the original real user
# processes and F07 swapping. The ordinary v1207 contract is unchanged.
if [ "$f07_swapslots" = 1 ] && {
    [ "$f07_concurrent" != 1 ] || [ "$f07_peak" != 1 ] ||
    [ "$f07_combined" != 1 ] || [ "$f07_high" != 1 ]; }; then
    echo 'v1321: require real concurrent, high-owner, swap-slot fixture' >&2
    exit 2
fi'''
assert source.count(guard) == 1, 'v1321 distinct pressure guard moved'
source = source.replace(guard, replacement, 1)
needle = '''        python3 "$self/daimos-f07-mm-high-v1204.py" \\
            "$work/source/system/kernel" small-only-v1206'''
assert source.count(needle) == 1, 'v1321 MM owner injector moved'
source = source.replace(needle, needle + '''
        python3 "$self/daimos-f07-mm-owner-pressure-v1321.py" \\
            "$work/source/system/kernel"''', 1)
needle = '"$self/daimos-f07-combined-verify-v1206.py"'
assert source.count(needle) == 1, 'v1321 combined verification moved'
source = source.replace(needle,
                        '"$self/daimos-f07-mm-owner-verify-v1321.py"', 1)
runner.write_text(source)
PY
sh -n "$work/runner-v1304.sh"
echo "v1321: prepared disposable combined real-MM guest at $work"
if [ "${V1321_PREPARE_ONLY:-0}" = 1 ]; then
    exit 0
fi

export V1304_PREPARE_ONLY=0 V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1
export V1205_TEST_CONCURRENT=1 V1206_TEST_COMBINED=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
echo 'v1321: starting physical 256K PDP-6 (24K process + 48K real MM occupancy)'
set +e
sh "$work/runner-v1304.sh" > "$work/runner.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1321: guest failed ($rc); NO no-partner acceptance" >&2
    tail -40 "$work/runner.log" >&2
    exit "$rc"
fi
guest=$(sed -n 's/^v1075 work: //p' "$work/runner.log" | tail -1)
test -n "$guest" && test -f "$guest/addresses"
set +e
python3 "$self/daimos-swap-no-partner-physical-v1303.py" \
    "$guest/addresses" "$guest/simh.out"
classified=$?
set -e
case "$classified" in
    0) echo 'v1321: completed guest with genuine MM no-partner PASS' ;;
    3) echo 'v1321: guest completed but no-partner UNEXERCISED' ;;
    *) echo "v1321: physical evidence invalid ($classified)" >&2
       exit "$classified" ;;
esac
echo "v1321: work=$work guest=$guest"
