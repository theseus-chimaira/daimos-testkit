#!/bin/sh
# Re-audit v1643 genuine read failure and calculate original 48K MM occupancy.
# A sampled physical checkpoint is not an unsampled whole-machine peak.
set -eu
: "${DAIMOS_REPO:?original DAIMOS source required}"
: "${PURE_PEAK_BUILD_V1651:?original v1643 48K build required}"
: "${PURE_PEAK_TRACE_V1651:?original v1643 48K trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-peak-v1651.XXXXXX")
trap 'echo "v1651 physical snapshot evidence: $work"' EXIT HUP INT TERM
export PURE_SECONDARY_BUILD_V1643="$PURE_PEAK_BUILD_V1651"
export PURE_SECONDARY_TRACE_V1643="$PURE_PEAK_TRACE_V1651"
sh "$testkit/tests/diagnostics/pure-secondary-read-v1643/run-audit-v1643.sh" \
    > "$work/original-v1643-audit.log"
cat "$work/original-v1643-audit.log"

python3 "$here/audit-v1651.py" \
    "$PURE_PEAK_BUILD_V1651/kcore.map" "$PURE_PEAK_TRACE_V1651" \
    "$testkit" > "$work/original-v1651-accounting.log"
cat "$work/original-v1651-accounting.log"
python3 "$here/mutate-v1651.py" "$testkit" \
    "$PURE_PEAK_BUILD_V1651/kcore.map" "$PURE_PEAK_TRACE_V1651" \
    "$work/invalid"
for mutant in arena dynamic full-pin; do
    if python3 "$here/audit-v1651.py" \
        "$PURE_PEAK_BUILD_V1651/kcore.map" \
        "$work/invalid/false-$mutant-v1651.trace" "$testkit" \
        > "$work/rejected-$mutant-v1651.log" 2>&1; then
        echo "FAIL v1651: fake physical $mutant MM accounting accepted" >&2
        exit 1
    fi
    if ! grep -q '^FAIL v1651 physical RAM accounting:' \
        "$work/rejected-$mutant-v1651.log"; then
        cat "$work/rejected-$mutant-v1651.log" >&2
        echo "FAIL v1651: $mutant negative did not reach accountant" >&2
        exit 1
    fi
    echo "PASS v1651: false physical $mutant witness rejected"
done
echo 'PASS v1651: accepted original six-stage 48K MM snapshot accounting'
