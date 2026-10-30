#!/bin/sh
# Compile PDP-6 scheduler and swap service, assert pressure-path wiring.
# This is a structural regression, not a full native workload PASS.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-swap-scheduler-v757.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc"
{ printf '.equ PROC_SWAP_VERIFY_PURE,0\n'; cat "$src/proc_swap_pdp6.s"; } > "$work/swap.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$work/swap.dobj" "$work/swap.s"
{ printf '.equ PROC_BOOT_USERS,1\n.equ PROC_STACK_WATERMARK,0\n.equ KINIT_STACK_WATERMARK,0\n'; cat "$src/proc_pdp6.s"; } > "$work/proc.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$work/proc.dobj" "$work/proc.s"
python3 - "$src/proc_pdp6.s" "$src/proc_swap_pdp6.s" <<'PY'
from pathlib import Path
import sys
sched, swap = (Path(p).read_text() for p in sys.argv[1:])
assert 'jumpg   1,proc_swap_service_pressure' in swap
assert 'jumpn   1,proc_swap_service_failed' in swap
assert 'pop     17,1\n        movem   1,proc_sched_cursor\n        jrst    kret_zero' in swap
assert 'movem   1,proc_swap_pressure_ticks' in swap
assert 'sos     proc_swap_pressure_ticks' in sched
assert sched.count('skipn   proc_swap_pressure_ticks') >= 2
assert 'proc_select_rt_swap:' in sched
PY
echo 'v757: scheduler pressure branches and PDP-6 assembler PASS; native runtime still pending'
