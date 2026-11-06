#!/bin/sh
# Exercise the production scheduler/timer leaves on native PDP-6 and prove
# the previous no-timer software-reschedule path fails the same fixture.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-f07-software-timer-v1252.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"

awk '/^[[:space:]]*\.equ[[:space:]]/ {print}' "$src" > "$work/prod.s"
printf '\n        .text\n        .globl proc_sched_resched_choose\n' \
    >> "$work/prod.s"
sed -n '/^proc_sched_resched_choose:$/,/^; Called once per qualified line-clock PI6/p' \
    "$src" | sed '$d' >> "$work/prod.s"
sed -n '/^proc_runq_add:$/,/^proc_runq_remove:$/p' "$src" | sed '$d' \
    >> "$work/prod.s"
sed -n '/^proc_timer_service:$/,/^proc_swap_victim:$/p' "$src" | sed '$d' \
    >> "$work/prod.s"

python3 - "$work/prod.s" "$work/old.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
needle = ('''        move    7,proc_timer_next
        tlne    7,PROC_TIMER_DUE_LH
        pushj   17,proc_timer_service
''')
if source.count(needle) != 1:
    raise SystemExit('v1252: production reschedule timer hook missing')
Path(sys.argv[2]).write_text(source.replace(needle, '', 1))
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
        "$self/daimos-f07-software-timer-v1252.s" \
        > "$work/$name.log" 2>&1 || {
            tail -50 "$work/$name.log" >&2
            return 1
        }
}
run_case f07-software-timer-v1252 0 "$work/prod.s"
run_case f07-software-timer-old-v1252 011 "$work/old.s"
echo 'v1252: due timer serviced before software PI6 selection; old path rejected PASS'
