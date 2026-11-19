#!/bin/sh
# v1650: original native PDP-6 PI6 slot-0 interrupted-PC/swap gate.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-slot0-v1650.XXXXXX")
trap 'echo "v1650 native evidence: $work"' EXIT HUP INT TERM
for mutation in none lower upper swap; do
    python3 "$here/extract-v1650.py" \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
        "$work/$mutation-v1650.s" "$mutation"
done
run() {
    name=$1
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 --timeout 20 \
        --workdir "$work/guest-$name" --name "pure-slot0-$name-v1650" \
        --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/$name-v1650.s" \
        "$here/test-native-v1650.s" >"$work/run-$name.log" 2>&1
}
if ! run none; then
    tail -65 "$work/run-none.log" >&2
    echo 'FAIL v1650: native original PI6 slot-0 swap exclusion' >&2
    exit 1
fi
echo 'PASS v1650: original PI6 MRES PC cannot preempt, even timer DUE'
for mutation in lower upper swap; do
    if run "$mutation"; then
        echo "FAIL v1650: invalid $mutation PI6 gate passed" >&2
        exit 1
    fi
    if ! grep -q '^FAIL: __test_exit: got ' "$work/run-$mutation.log"; then
        tail -30 "$work/run-$mutation.log" >&2
        echo "FAIL v1650: invalid $mutation did not run native" >&2
        exit 1
    fi
    echo "PASS v1650: invalid $mutation PI6 gate rejected"
done
