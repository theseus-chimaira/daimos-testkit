#!/bin/sh
# Repeated real checked-free failure preserves the exact DISK owner.
# This diagnoses repeatability, NOT bounded physical scheduler retries.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
output=$(KEEP_TEST=1 sh "$self/daimos-swap-checked-scheduler-v1493.sh")
printf '%s\n' "$output"
work=$(printf '%s\n' "$output" |
    sed -n 's/^v1493 work: //p' | tail -1)
test -n "$work" && test -f "$work/production-v1493.s"
cat "$self/daimos-backstore-permanent-refusal-v1505.s" \
    "$work/fixture-v1493.s" > "$work/driver-v1505.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 900000 --timeout 30 \
    --workdir "$work/repeat" --name backstore-permanent-v1505 \
    --expect __test_exit=0 --expect attempt_count_v1505=6 \
    --expect event_calls_v1505=6 --expect event_slot_v1505=2 \
    --expect event_kind_v1505=1 --expect unexpected_exchange_v1505=0 \
    --expect repair_return_v1505=01002 \
    --expect __rollback_calls_v1405=6 --expect __publish_calls_v1405=1 \
    --expect __invariant_calls_v1405=0 \
    --expect __read_calls_v1405=7 --expect __read_bad_v1405=0 \
    --expect __expect_calls_v1405=7 --expect __store_bad_v1405=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1493.s" \
    "$work/driver-v1505.s" > "$work/repeat.log" 2>&1 || {
        tail -70 "$work/repeat.log" >&2
        exit 1
    }
echo 'PASS v1505: six corrupt bitmap retries retain exact DISK owner'
echo 'PASS v1505: no premature RESIDENT/READY_ONCE, no unpin/MM leak'
echo 'PASS v1505: explicit bit repair permits one checked restore'
echo 'v1505: repeated calls are intentionally forced; permanent failure remains OPEN'
