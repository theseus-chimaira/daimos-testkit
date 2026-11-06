#!/bin/sh
# Extract and execute both actual PDP-6 wait gates, including mutants.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-pipe-fatal-v1261.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
{
    printf '        .equ PROC_WAIT_INTR_LH,060000\n'
    printf '        .text\n.globl proc_wait_event_intr\n'
    sed -n '/^proc_wait_event_intr:$/,/^proc_wait_event:$/p' "$src" | sed '$d'
    printf '        .globl proc_wait_intr_return\n'
    sed -n '/^proc_wait_intr_return:$/,/^\/\*\*$/p' "$src" | sed '$d'
} > "$work/wait.s"

python3 - "$work/wait.s" "$work" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
directory = Path(sys.argv[2])
term = '        tlne    2,0116'
pipe = '        trne    2,1'
if source.count(term) != 2 or source.count(pipe) != 2:
    raise SystemExit('v1261: missing paired fatal wait checks')

# Each mutant must alter just one of the two actual native leaves.
def make_mutant(needle, replacement, occurrence, filename):
    start = 0
    for _ in range(occurrence + 1):
        found = source.find(needle, start)
        if found < 0:
            raise SystemExit('v1261: wrong source occurrence')
        start = found + len(needle)
    broken = source[:found] + replacement + source[start:]
    (directory / filename).write_text(broken)

make_mutant(term, '        tlne    2,0100', 0, 'old-pre-term.s')
make_mutant(term, '        tlne    2,0100', 1, 'old-post-term.s')
make_mutant(pipe, '        trne    2,0', 0, 'old-pre-pipe.s')
make_mutant(pipe, '        trne    2,0', 1, 'old-post-pipe.s')
PY

run_case()
{
    name=$1
    expected=$2
    source=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 150000 --timeout 20 \
        --workdir "$work/$name" --name "$name" \
        --expect "__test_exit=$expected" \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$self/daimos-pipe-fatal-wait-v1261.s" \
        > "$work/$name.log" 2>&1 || {
            tail -56 "$work/$name.log" >&2
            return 1
        }
}
run_case pipe-fatal-v1261 0 "$work/wait.s"
run_case pipe-pre-term-old-v1261 1 "$work/old-pre-term.s"
run_case pipe-post-term-old-v1261 2 "$work/old-post-term.s"
run_case pipe-pre-pipe-old-v1261 3 "$work/old-pre-pipe.s"
run_case pipe-post-pipe-old-v1261 4 "$work/old-post-pipe.s"
echo 'v1261: native pre/post TERM, PIPE and ALRM interruption; four old mutants PASS'
