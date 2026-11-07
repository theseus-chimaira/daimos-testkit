#!/bin/sh
# A genuine user process releases physical MM after real swap cooldown.
# All modified assembly/C is in a disposable guest build, not DAIMOS.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1327_PREPARE_ONLY=1 sh \
    "$self/daimos-swap-no-partner-fullguest-v1327.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1327: prepared disposable combined real-MM guest at //p' | tail -1)
test -n "$work" && test -f "$work/runner-v1304.sh"

python3 - "$work/runner-v1304.sh" "$work/pressure-init-v1304.c" \
    "$work/runner-v1336.sh" <<'PY'
from pathlib import Path
import sys

original, guest_file, output = (Path(p) for p in sys.argv[1:])
runner = original.read_text()
guest = guest_file.read_text()

old = '''        python3 "$self/daimos-f07-mm-owner-pressure-v1327.py" \\
            "$work/source/system/kernel"'''
assert runner.count(old) == 1, 'v1336 real-MM source-injection anchor moved'
runner = runner.replace(old, old + '''
        python3 "$self/daimos-f07-independent-releaser-v1336.py" \\
            "$work/source/system/kernel"''', 1)
old = 'daimos-simh-swap-live-sampler-v1326.py'
assert runner.count(old) == 1
runner = runner.replace(old, 'daimos-simh-swap-live-sampler-v1332.py', 1)
old = '--addresses "$work/addresses" \\'
assert runner.count(old) == 1
runner = runner.replace(old, old + '\n        --kcore-map "$build/kcore.map" \\', 1)
old = '"$self/daimos-f07-mm-owner-verify-v1327.py"'
assert runner.count(old) == 1
runner = runner.replace(
    old, '"$self/daimos-swap-independent-release-verify-v1336.py"', 1)

# The independent user prints one '&' witness on successful MM release.
# Require the strict final verifier to check it, but remove it from
# the older fixed v1075 requester/witness milestone comparison.
old = "tr -d '+~^@%*?{}|'"
assert runner.count(old) == 1, 'v1336 terminal witness sanitization moved'
runner = runner.replace(old, "tr -d '+~^@%*?{}|&'", 1)

# Publish source-linked witness words to the original post-HALT SIMH
# examination list; do not obtain values from the host or a stub.
old = '''        done
    fi
    if [ "$f07_concurrent" = 1 ]; then'''
assert runner.count(old) == 1, 'v1336 postflight counter map changed'
new = '''        done
        for name in released spinner_base release_pressure; do
            sym="daimos_f07_${name}_v1336"
            if [ "$name" = spinner_base ]; then
                sym=daimos_f07_spinner_base_v1336
            fi
            if [ "$name" = release_pressure ]; then
                sym=daimos_f07_release_pressure_v1336
            fi
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \
                "$build/kcore.map")
            test -n "$addr" || { echo "v1336: missing $sym" >&2; exit 1; }
            printf 'f07r_%s %s\\n' "$name" "$addr" >> "$work/addresses"
        done
    fi
    if [ "$f07_concurrent" = 1 ]; then'''
runner = runner.replace(old, new, 1)

# The original S user process is independently runnable. After 4
# genuine MM owner extents are allocated, its VM is pinned through
# production mm_pin. It polls the actual slot-0 cooldown count and
# releases the owners with the real mm_free and mm_unpin functions.
old = '''                if (argv[1][1] ==
                    TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ')) {
                        for (;;) {
                                if (dsys_sleep(2U) != 0)
                                        (void)dsys_exit(076);
                        }
                }'''
new = '''                if (argv[1][1] ==
                    TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ')) {
#if V1204_TEST_F07_HIGH
                        kword_t cooldowns;
                        for (;;) {
                                cooldowns = dsys_brk(0777767UL);
                                if (cooldowns == ~(kword_t)0UL)
                                        (void)dsys_exit(076);
                                if (cooldowns != 0UL) {
                                        if (dsys_brk(0777763UL) != 0UL)
                                                (void)dsys_exit(076);
                                        (void)dsys_writechar(1, '&');
                                        break;
                                }
                                if (dsys_sleep(0100U) != 0)
                                        (void)dsys_exit(076);
                        }
#endif
                        for (;;) {
                                if (dsys_sleep(2U) != 0)
                                        (void)dsys_exit(076);
                        }
                }'''
assert guest.count(old) == 1, 'v1336 actual independent user stage moved'
guest = guest.replace(old, new, 1)

# Owner freeing is now done in S after the *observed* no-partner
# pressure. Do not run the old late INIT cleanup a second time.
old = '''#if V1204_TEST_F07_HIGH
        /* No pressure allocation survives into the final PID/VM/FILE
         * accounting checks; every base is type/owner-verified by MM. */
        if (dsys_brk(0777763UL) != 0UL)
                fail('u');
#endif'''
assert guest.count(old) == 1, 'v1336 old late release moved'
guest = guest.replace(old, '''#if V1204_TEST_F07_HIGH
        /* Independent S already freed every owner after real pressure. */
#endif''', 1)
assert guest.count('dsys_brk(0777763UL)') == 1
assert runner.count('daimos-f07-independent-releaser-v1336.py') == 1
original.parent.joinpath('pressure-init-v1304.c').write_text(guest)
output.write_text(runner)
PY

sh -n "$work/runner-v1336.sh"
echo "v1336: prepared independent-resident real-MM guest at $work"
if [ "${V1336_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_INTERVAL=${V1306_INTERVAL:-90}
export V1306_COUNT=${V1306_COUNT:-24}
export V1306_TIMEOUT=${V1306_TIMEOUT:-3610}
echo 'v1336: boot genuine 256K PDP-6, 32K real MM owner, user releaser'
set +e
sh "$work/runner-v1336.sh" > "$work/runner-v1336.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "v1336: full guest failed ($rc), not accepted" >&2
    tail -55 "$work/runner-v1336.log" >&2
    exit "$rc"
fi
guest=$(sed -n 's/^v1075 work: //p' "$work/runner-v1336.log" | tail -1)
test -n "$guest" && test -f "$guest/addresses"
python3 "$self/daimos-swap-independent-release-verify-v1336.py" \
    "$guest/addresses" "$guest/simh.out"
echo "v1336: work=$work guest=$guest"
