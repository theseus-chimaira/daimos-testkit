#!/bin/sh
# Original physical PDP-6 48K 36-bit six-PACKED source entropy.
set -eu
: "${PURE_SUFFIX_BUILD_V1657:?original v1654 physical 48K build required}"
: "${PURE_SUFFIX_TRACE_V1657:?original v1654 accepted MM trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-suffix-v1657.XXXXXX")
trap 'echo "v1657 physical suffix evidence: $work"' EXIT HUP INT TERM
python3 "$here/prepare-v1657.py" "$PURE_SUFFIX_BUILD_V1657" \
    "$PURE_SUFFIX_TRACE_V1657" "$kit" "$work"
port=$((37000 + ($$ % 7900)))
sh "$kit/tests/lib/daimos-simh-headless.sh" \
    "$work/sample.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(
    cd "$PURE_SUFFIX_BUILD_V1657"
    TERM=dumb timeout -k 3s "${PURE_SUFFIX_TIMEOUT_V1657:-950}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
if [ "$rc" -ne 0 ]; then
    echo "FAIL v1657: physical simulator status=$rc" >&2
    tail -40 "$work/trace.clean" >&2
    exit 1
fi
python3 "$here/audit-v1657.py" "$work/trace.clean" \
    "$work/intervals-v1657.txt" >"$work/measure-v1657.log"
cat "$work/measure-v1657.log"
python3 "$here/mutate-v1657.py" "$work/trace.clean" "$work/invalid"
for mutant in wrong-word missing-word missing-halt; do
    if python3 "$here/audit-v1657.py" \
        "$work/invalid/$mutant-v1657.trace" \
        "$work/intervals-v1657.txt" \
        >"$work/rejected-$mutant.log" 2>&1; then
        echo "FAIL v1657: false physical $mutant accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1657 original source density:' \
        "$work/rejected-$mutant.log" || {
        tail -20 "$work/rejected-$mutant.log" >&2
        exit 1
    }
    echo "PASS v1657: false original physical $mutant witness rejected"
done
