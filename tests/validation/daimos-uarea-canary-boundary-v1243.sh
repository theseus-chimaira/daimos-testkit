#!/bin/sh
# Execute actual PDP-6 RUN u-area canary loop and its negative mutant.
set -eu
: "$DAIMOS_REPO" "$PDP10_PREFIX"
if [ -z "$DAIMOS_REPO" ] || [ -z "$PDP10_PREFIX" ]; then
    echo 'v1243: DAIMOS_REPO and PDP10_PREFIX required' >&2
    exit 2
fi
if [ -z "$TMPDIR" ]; then TMPDIR=$HOME/tmp; fi
export TMPDIR
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-uarea-canary-v1243.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/proc_run.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_late.c" \
    "$work/canary-leaf.s" <<'PY'
from pathlib import Path
import sys

assembler = Path(sys.argv[1]).read_text()
c_source = Path(sys.argv[2]).read_text()
begin = ('.if PROC_STACK_WATERMARK\n'
         '        move    1,014\n'
         '        addi    1,PROC_USTACK_BASE+1\n')
if assembler.count(begin) != 1:
    raise SystemExit('v1243: native RUN canary entry moved')
start = assembler.index(begin) + len('.if PROC_STACK_WATERMARK\n')
end = assembler.index('.endif', start)
leaf = assembler[start:end]
if 'PROC_SWAP_BACKING_OFFSET' not in leaf:
    raise SystemExit('v1243: RUN canary bound does not protect backing')
if 'i < (unsigned int)PROC_SWAP_BACKING_OFFSET; ++i)' not in c_source:
    raise SystemExit('v1243: KINIT canary bound does not protect backing')
out = ('.text\n'
       '.equ PROC_USTACK_BASE,070\n'
       '.equ PROC_SWAP_BACKING_OFFSET,0406\n'
       '.equ PROC_UAREA_WORDS,0410\n'
       '.globl proc_run_canary_fill_v1243\n'
       'proc_run_canary_fill_v1243:\n' + leaf +
       '        popj    17,\n')
Path(sys.argv[3]).write_text(out)
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 20000 --timeout 20 \
    --workdir "$work/run" --name daimos-uarea-canary-v1243 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/canary-leaf.s" \
    "$self/daimos-uarea-canary-boundary-v1243.s" \
    > "$work/result.log" 2>&1 || {
        tail -35 "$work/result.log" >&2
        exit 1
    }

# Original RUN mistakenly wrote physical-address canaries into backing/BRK.
sed 's/addi    2,PROC_SWAP_BACKING_OFFSET/addi    2,PROC_UAREA_WORDS/' \
    "$work/canary-leaf.s" > "$work/old-leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 20000 --timeout 20 \
    --workdir "$work/old" --name daimos-uarea-overwrite-v1243 \
    --expect __test_exit=1 \
    "$self/daimos-test-crt0-v1.s" "$work/old-leaf.s" \
    "$self/daimos-uarea-canary-boundary-v1243.s" \
    > "$work/old.log" 2>&1 || {
        tail -35 "$work/old.log" >&2
        exit 1
    }
echo 'v1243: native RUN canaries preserve backing/BRK; old mutant rejected PASS'
