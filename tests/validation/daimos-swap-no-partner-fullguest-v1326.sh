#!/bin/sh
# Disposable 256K PDP-6 no-partner experiment using genuine MM pins.
# No extra physical extent, no fake MM return value or kernel policy edit.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export KEEP_TEST=1 V1323_PREPARE_ONLY=1
output=$(sh "$self/daimos-swap-no-partner-fullguest-v1323.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n 's/^v1323: prepared disposable combined real-MM guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1304.sh"

python3 - "$work/runner-v1304.sh" "$work/pressure-init-v1304.c" <<'PY'
from pathlib import Path
import sys

runner, user = (Path(p) for p in sys.argv[1:])
script = runner.read_text()
inject = '''        python3 "$self/daimos-f07-mm-owner-pressure-v1323.py" \\
            "$work/source/system/kernel"'''
assert script.count(inject) == 1
script = script.replace(inject, inject + '''
        python3 "$self/daimos-f07-mm-pin-residents-v1326.py" \\
            "$work/source/system/kernel"''', 1)
old = '"$self/daimos-f07-mm-owner-verify-v1323.py"'
assert script.count(old) == 1
script = script.replace(old,
                        '"$self/daimos-f07-mm-pin-verify-v1326.py"', 1)
sampler = '"$self/daimos-simh-swap-live-sampler-v1306.py"'
assert script.count(sampler) == 1
script = script.replace(
    sampler, '"$self/daimos-simh-swap-live-sampler-v1324.py"', 1)
runner.write_text(script)

source = user.read_text()
old = 'dsys_brk(0777762UL)'
assert source.count(old) == 1
# Encode the actual requester PID in the otherwise test-only argument.
# This process must remain unpinned to preserve its fatal OOM lifecycle.
source = source.replace(old,
                        'dsys_brk(0777762UL | ((kword_t)requester << 18U))',
                        1)
release = '''#if V1204_TEST_F07_HIGH
        /* No pressure allocation survives into the final PID/VM/FILE
         * accounting checks; every base is type/owner-verified by MM. */
        if (dsys_brk(0777763UL) != 0UL)
                fail('u');
#endif'''
assert source.count(release) == 1
source = source.replace(release, '', 1)
anchor = '''        wait_status((unsigned int)requester,
            V1075_TEST_OOM_ENABLED ? V1075_OOM_STATUS : 070U);'''
assert source.count(anchor) == 1
release_early = '''        /* v1326: unpin every test-owned resident image BEFORE any
         * subsequent TERM/WAIT teardown can free those process VMs.
         * The preceding three 0100-tick sleeps provide a real PI6
         * cooldown interval for the physical no-partner test. */
#if V1204_TEST_F07_HIGH
        if (dsys_brk(0777763UL) != 0UL)
                fail('u');
#endif
'''
source = source.replace(anchor, release_early + anchor, 1)
user.write_text(source)
PY
sh -n "$work/runner-v1304.sh"
echo "v1326: prepared disposable real-MM-pin guest at $work"
if [ "${V1326_PREPARE_ONLY:-0}" = 1 ]; then
    exit 0
fi

export V1323_PREPARE_ONLY=0 V1283_PRODUCTION_OOM_DEFAULT=1
export V1203_TEST_F07_PEAK=1 V1204_TEST_F07_HIGH=1
export V1205_TEST_CONCURRENT=1 V1206_TEST_COMBINED=1
export V1207_TEST_SWAPSLOTS=1 V1150_TEST_HELD_PROVIDER=1
export V1159_TEST_PROTECTED=1 V1160_RELEASE_MEDIA=1
export V1219_SWAP_ALLOCATOR_PROBE=1 V1075_TEST_OOM_ENABLED=1
export V1160_EVIDENCE_DIR="$work/media"
echo 'v1326: booting physical 256K PDP-6 with real resident MM pins'
set +e
sh "$work/runner-v1304.sh" > "$work/runner.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1326: guest failed ($rc); no full-system acceptance" >&2
    tail -45 "$work/runner.log" >&2
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
    0) echo 'v1326: genuine no-partner MM pressure and guest recovery PASS' ;;
    3) echo 'v1326: completed guest, no-partner branch NOT EXERCISED' ;;
    *) echo "v1326: physical MM evidence invalid ($classified)" >&2
       exit "$classified" ;;
esac
echo "v1326: work=$work guest=$guest"
