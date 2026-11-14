#!/bin/sh
# Native source-linked PDP-6 LOGSTORE torn write, cursor rollback, retry,
# plus executed mutations that must not reach a successful oracle exit.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-logstore-fault-rollback-v1577.XXXXXX")
if [ "${V1577_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1577 native evidence: $work"
fi

python3 - "$DAIMOS_REPO/system/kernel/storage/logstore_runtime.s" "$work" <<'PY'
from pathlib import Path
import sys

original = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])
mutants = (
    ('ignore-error', '        jumpn   1,logstore_append_done',
        '        move    5,5'),
    ('skip-sequence', '        aos     logstore_mres_state+2',
        '        move    5,5'),
    ('skip-slot', '        hrrm    7,logstore_mres_state+3',
        '        move    5,5'),
    ('skip-wake', '        setom   logstore_mres_state+5',
        '        move    5,5'),
)
for name, before, after in mutants:
    assert original.count(before) == 1, (name, original.count(before))
    (out / (name + '.s')).write_text(original.replace(before, after, 1))
print('PASS v1577: exact real MRES fault path plus four source mutants')
PY

run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 2000000 \
        --timeout 30 --workdir "$work/run-$name" \
        --name "logstore-fail-$name-v1577" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-logstore-fault-rollback-v1577.s" \
        "$source" > "$work/$name.log" 2>&1
}

if ! run original "$DAIMOS_REPO/system/kernel/storage/logstore_runtime.s"; then
    tail -60 "$work/original.log" >&2
    exit 1
fi
echo 'PASS v1577: real PDP-6 failed LOGSTORE write retained cursor, retry committed'
for name in ignore-error skip-sequence skip-slot skip-wake; do
    if run "$name" "$work/$name.s"; then
        echo "FAIL v1577: accepted $name mutant" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/$name.log" || {
        tail -50 "$work/$name.log" >&2
        echo "FAIL v1577: $name did not execute its assertion" >&2
        exit 1
    }
    echo "PASS v1577: rejected source mutation $name"
done
