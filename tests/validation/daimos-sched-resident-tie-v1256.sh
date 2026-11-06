#!/bin/sh
# Link and run the *actual* production PDP-6 selector, including a valid old
# variant proving its equal-priority disk-preference regression.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-sched-resident-tie-v1256.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
{
    printf '.text\n.globl proc_sched_resched_select\n'
    sed -n '/^        \.equ    PROC_WORDS,3$/,/^        \.text$/p' "$src"
    sed -n '/^proc_sched_resched_select:$/,/^\/\*\*$/p' "$src" | sed '$d'
} > "$work/selector.s"

python3 - "$work/selector.s" "$work/selector-old.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
start = source.index('proc_select_rank_locality_v1256:\n')
end = source.index('proc_select_compare:\n', start)
if 'addi    2,0400\n' not in source[start:end]:
    raise SystemExit('v1256: no valid locality implementation')
Path(sys.argv[2]).write_text(source[:start] +
                              'proc_select_rank_locality_v1256:\n' +
                              source[end:])
PY

run_case()
{
    name=$1
    expected=$2
    source=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
        --workdir "$work/$name" --name "$name" \
        --expect "__test_exit=$expected" \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$self/daimos-sched-resident-tie-v1256.s" \
        > "$work/$name.log" 2>&1 || {
            tail -55 "$work/$name.log" >&2
            return 1
        }
}
run_case resident-locality-v1256 0 "$work/selector.s"
run_case resident-old-v1256 1 "$work/selector-old.s"
echo 'v1256: native resident tie, strict priority, all-resident/disk, fatal and old mutant PASS'
