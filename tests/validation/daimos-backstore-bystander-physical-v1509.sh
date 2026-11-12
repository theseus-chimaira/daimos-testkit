#!/bin/sh
# Booted 256K PDP-6: a real independent spinner runs during permanent
# selected BACKSTORE refusal. No production source/ABI/RAM changes.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 "$self/daimos-backstore-bystander-user-selftest-v1509.py"
python3 "$self/daimos-backstore-bystander-verify-v1509.py" --self-test \
    > "$TMPDIR/daimos-bystander-verifier-selftest-v1509.log"
tail -4 "$TMPDIR/daimos-bystander-verifier-selftest-v1509.log"

output=$(V1508_PREPARE_ONLY=1 sh \
    "$self/daimos-backstore-persistent-physical-v1508.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" | sed -n \
    's/^v1508: prepared bounded persistent-refusal physical guest at //p' | \
    tail -1)
test -n "$work" && test -f "$work/runner-v1508.sh" && \
    test -f "$work/sampler-v1508.py"

python3 - "$work/runner-v1508.sh" "$work/runner-v1509.sh" \
    "$work/sampler-v1508.py" "$work/sampler-v1509.py" <<'PY'
from pathlib import Path
import sys

src, dest, original_sampler, target_sampler = map(Path, sys.argv[1:])
runner = src.read_text()
old = 'requester_source="$v1304_user_source"'
assert runner.count(old) == 1, 'v1509 F07 compile anchor moved'
runner = runner.replace(old,
    '# v1509: move only disposable spinner TERM/WAIT past extra children.\n'
    'python3 "$self/daimos-backstore-bystander-user-v1509.py" \\\n'
    '    "$v1304_user_source"\n' + old, 1)
dest.write_text(runner)

sampler = original_sampler.read_text()
old = 'FIELDS = (\n'
assert sampler.count(old) == 1
sampler = sampler.replace(old, old + "    'spinner',\n", 1)
old = 'if __name__ == \'__main__\':\n'
assert sampler.count(old) == 1
sampler = sampler.replace(old, '''# v1509: actual PID5 SLEEP syscalls (v1150 production-source witness).
_v1508_summary_v1509 = summary
def summary(number, pc, values):
    return _v1508_summary_v1509(number, pc, values) + (
        ' spinner=%d' % values['spinner'])

''' + old, 1)
# A clean v1508 checkout has the original fixed sample limit; a parallel
# in-progress v1508 sampler may already have an adaptive fault horizon.
# Support both exact source shapes without modifying that other work.
# Keep the absolute sampler --timeout; the extra count is diagnostic only.
old = 'args.count = max(args.count, taken + 3)'
if sampler.count(old) == 1:
    sampler = sampler.replace(old,
        'args.count = max(args.count, taken + 5)', 1)
else:
    assert sampler.count(old) == 0, 'ambiguous adaptive sampler'
    anchor = '                        if args.stop_after_samples and taken == args.count:\n'
    assert sampler.count(anchor) == 1, 'v1509 sampler stop gate moved'
    guard = (
        '                        # v1509: stop only after sufficient actual\n'
        '                        # fault-on samples; no fake guest success.\n'
        '                        if args.stop_after_samples:\n'
        '                            if not values[\'v1494_faults\']:\n'
        '                                args.count = max(args.count, taken + 4)\n'
        '                            elif \'v1509_first_fault_sample\' not in locals():\n'
        '                                v1509_first_fault_sample = taken\n'
        '                                args.count = max(args.count, taken + 5)\n')
    sampler = sampler.replace(anchor, guard + anchor, 1)
target_sampler.write_text(sampler)
runner = dest.read_text()
old = str(original_sampler)
assert runner.count(old) == 1
dest.write_text(runner.replace(old, str(target_sampler), 1))
PY
sh -n "$work/runner-v1509.sh"
python3 -m py_compile "$work/sampler-v1509.py"
echo "v1509: prepared persistent fault and PID5 progress guest at $work"
if [ "${V1509_PREPARE_ONLY:-0}" = 1 ]; then
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
export V1306_TIMEOUT=${V1306_TIMEOUT:-1800}
unset V1344_DIAG_STOP
echo 'v1509: booting disposable 256K PDP-6 with live PID5 bystander'
set +e
sh "$work/runner-v1509.sh" > "$work/runner-v1509.log" 2>&1
rc=$?
set -e
guest=$(sed -n 's/.*v1075 work: //p' "$work/runner-v1509.log" | \
    tail -1)
if [ -z "$guest" ] || [ ! -s "$guest/simh-sampler.log" ] || \
    [ ! -s "$guest/simh.out" ]; then
    echo 'v1509: missing physical bystander evidence' >&2
    tail -65 "$work/runner-v1509.log" >&2
    exit 1
fi
grep -q 'intentionally stopped after diagnostic samples' \
    "$guest/simh.out.raw-v1306.log" || {
        echo 'v1509: sampler did not complete its bounded run' >&2
        tail -40 "$guest/simh-sampler.log" >&2
        exit 1
    }
python3 "$self/daimos-backstore-bystander-verify-v1509.py" \
    "$guest/simh-sampler.log" "$guest/simh.out"
echo "v1509: diagnostic runner_rc=$rc; no normal HALT claimed"
echo "v1509: evidence work=$work guest=$guest"
