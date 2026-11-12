#!/bin/sh
# v1508 bounded physical 256K guest, permanently refused checked release.
# Deliberately stops after read-only diagnostic samples: NOT a HALT test.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(V1504_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-owner-return-v1504.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" |
    sed -n 's/^v1504: prepared 256K physical owner-return runner at //p' |
    tail -1)
test -n "$work" && test -f "$work/runner-v1504.sh"

python3 - "$work/runner-v1504.sh" "$work/runner-v1508.sh" \
    "$self/daimos-simh-swap-live-sampler-v1344.py" \
    "$work/sampler-v1508.py" <<'PY'
from pathlib import Path
import sys

src, dst, original_sampler, target_sampler = map(Path, sys.argv[1:])
text = src.read_text()
old = 'daimos-backstore-owner-return-v1504.py'
assert text.count(old) == 1
text = text.replace(old, 'daimos-backstore-persistent-physical-v1508.py')
old = '"$self/daimos-simh-swap-live-sampler-v1344.py"'
assert text.count(old) == 1
text = text.replace(old, '"' + str(target_sampler) + '"', 1)
old = '--timeout "${V1306_TIMEOUT:-1810}")'
assert text.count(old) == 1
text = text.replace(old,
    '--timeout "${V1306_TIMEOUT:-1810}" --stop-after-samples)', 1)
old = 'if [ "${V1306_LIVE_SAMPLER:-0}" = 1 ]; then'
assert text.count(old) == 1
extra = r'''        for name in record_count last_record last_meta last_vm \
                    last_sched last_retry last_fdctl; do
            sym="daimos_v1508_$name"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' \
                "$build/kcore.map")
            test -n "$addr" || { echo "v1508: missing $sym" >&2; exit 1; }
            printf 'v1508_%s %s\n' "$name" "$addr" >> "$work/addresses"
        done
        # The v1344 sampler requires this physical controller witness,
        # which some F07 profiles omit from the earlier optional map.
        if ! grep -q '^drm236_active_request ' "$work/addresses"; then
            addr=$(awk '$1 == "drm236_active_request" {print $2}' \
                "$build/kcore.map")
            test -n "$addr" || { echo "v1508: no controller map" >&2; exit 1; }
            printf 'drm236_active_request %s\n' "$addr" >> "$work/addresses"
        fi
'''
text = text.replace(old, extra + old, 1)
dst.write_text(text)

sampler = original_sampler.read_text()
old = "FIELDS = (\n"
assert sampler.count(old) == 1
fields = (
    'v1494_armed', 'v1494_faults', 'v1494_free_calls',
    'v1494_repairs', 'v1494_slot', 'v1494_first', 'v1494_blocks',
    'v1495_failed_entry', 'v1499_events',
    'v1504_owner_term_count', 'v1504_private_fatal_count',
    'v1504_finish_count', 'v1504_zombie_count',
    'v1508_record_count', 'v1508_last_record',
    'v1508_last_meta', 'v1508_last_vm', 'v1508_last_sched',
    'v1508_last_retry', 'v1508_last_fdctl')
sampler = sampler.replace(old, old + ''.join(
    '    %r,\n' % name for name in fields), 1)
old = "if __name__ == '__main__':\n"
assert sampler.count(old) == 1
extra = """
_v1306_original_summary_v1508 = summary
def summary(number, pc, values):
    original = _v1306_original_summary_v1508(number, pc, values)
    return original + (
        ' fault=%d refused=%d repairs=%d slot=%d first=%d blocks=%d'
        ' failed_service=%d events=%d owner_term=%d'
        ' private_close=%d finish=%d zombie=%d'
        ' record_count=%d record=%012o meta=%012o vm=%012o'
        ' sched=%012o retry=%012o fdctl=%012o' % (
        values['v1494_faults'], values['v1494_free_calls'],
        values['v1494_repairs'], values['v1494_slot'],
        values['v1494_first'], values['v1494_blocks'],
        values['v1495_failed_entry'], values['v1499_events'],
        values['v1504_owner_term_count'],
        values['v1504_private_fatal_count'],
        values['v1504_finish_count'], values['v1504_zombie_count'],
        values['v1508_record_count'], values['v1508_last_record'],
        values['v1508_last_meta'], values['v1508_last_vm'],
        values['v1508_last_sched'], values['v1508_last_retry'],
        values['v1508_last_fdctl']))

"""
sampler = sampler.replace(old, extra + old, 1)
target_sampler.write_text(sampler)
PY
sh -n "$work/runner-v1508.sh"
python3 -m py_compile "$work/sampler-v1508.py"
echo "v1508: prepared bounded persistent-refusal physical guest at $work"
if [ "${V1508_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_INTERVAL=${V1306_INTERVAL:-35}
export V1306_COUNT=${V1306_COUNT:-20}
export V1306_TIMEOUT=${V1306_TIMEOUT:-1500}
unset V1344_DIAG_STOP
echo 'v1508: booting disposable 256K PDP-6 permanent-refusal diagnostic'
set +e
sh "$work/runner-v1508.sh" > "$work/runner-v1508.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1508.log" |
    tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh-sampler.log" ]; then
    echo 'v1508: missing physical sampler evidence' >&2
    tail -55 "$work/runner-v1508.log" >&2
    exit 1
fi
python3 "$self/daimos-backstore-persistent-verify-v1508.py" \
    "$guest/simh-sampler.log" "$guest/simh.out"
echo "v1508: bounded diagnostic runner_rc=$rc (not F07 HALT acceptance)"
echo "v1508: evidence work=$work guest=$guest"
