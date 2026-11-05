#!/bin/sh
# Run actual backstore bitmap exhaustion, reserve and recovery on PDP-6.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-backstore-capacity-v1156.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1156 retained: $work"; fi' EXIT HUP INT TERM
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 200000 --timeout 20 \
    --workdir "$work/run" --name oom-backstore-capacity-v1156 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$DAIMOS_REPO/system/kernel/storage/backstore.s" \
    "$self/daimos-oom-backstore-capacity-v1156.s" \
    >"$work/log" 2>&1 || { tail -65 "$work/log" >&2; exit 1; }

# Test the checker itself: each unsafe mutation must assemble and
# execute, but must be rejected by the exact backing-owner counters.
python3 - "$DAIMOS_REPO/system/kernel/storage/backstore.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
mutants = {
    'refusal-increments-owner': (
        'backstore_alloc_fail_fast:\n        seto    1,',
        'backstore_alloc_fail_fast:\n'
        '        aos     backstore_blocks_used\n        seto    1,'),
    'free-increments-owner': (
        'backstore_free_count:\n        movn    3,011\n'
        '        addm    3,backstore_blocks_used',
        'backstore_free_count:\n        move    3,011\n'
        '        addm    3,backstore_blocks_used'),
}
for name, (before, after) in mutants.items():
    assert source.count(before) == 1, ('source anchor changed', name)
    (work / ('unsafe-' + name + '.s')).write_text(
        source.replace(before, after, 1))
PY
for name in refusal-increments-owner free-increments-owner; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 --timeout 20 \
        --workdir "$work/run-$name" --name "oom-v1156-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$work/unsafe-$name.s" \
        "$self/daimos-oom-backstore-capacity-v1156.s" \
        >"$work/log-$name" 2>&1; then
        echo "v1156: unsafe mutation unexpectedly passed: $name" >&2
        exit 1
    fi
    if ! grep -q '__test_exit' "$work/log-$name"; then
        echo "v1156: mutant failed before the owner-accounting check: $name" >&2
        tail -35 "$work/log-$name" >&2
        exit 1
    fi
    echo "v1156: rejected unsafe mutation $name"
done
echo 'v1156: real backing bitmap exhausted with and without reserve, failed allocation leaves ownership unchanged, free/reallocate accounting PASS'
