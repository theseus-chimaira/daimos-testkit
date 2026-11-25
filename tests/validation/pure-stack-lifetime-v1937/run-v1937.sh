#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-stack-lifetime-v1937.XXXXXX")
trap 'echo "v1937 native evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel/proc" "$work" <<'PY'
from pathlib import Path
import sys
src,work=map(Path,sys.argv[1:])
s=(src/'proc_pdp6.s').read_text()
b=(src/'proc_pure_backing_pdp6.s').read_text()
# Take the real layout equates, not a second set of geometry constants.
head=s[:s.index('proc_parent_waitable_v1768:')]
eq='\n'.join(x for x in head.splitlines() if x.strip().startswith('.equ '))
base='.text\n.equ PROC_STACK_WATERMARK,0\n'+eq+'\n'
for name in ('proc_finish_slot','proc_finish_slot_owner_v932','proc_slot_discard',
             'proc_uarea_release','proc_event_apply','proc_exit_current'):
    base+='.globl '+name+'\n'
base+=s[s.index('proc_parent_waitable_v1768:'):s.index('proc_finish_service_v881:')]
base+=s[s.index('proc_slot_discard:'):s.index('proc_tty_release_session:')]
base+=s[s.index('proc_event_apply:'):s.index('proc_event_nonfatal:')]
base+=s[s.index('proc_exit_current:'):s.index('/**',s.index('proc_exit_release_failed:'))]
base+=b[b.index('        .globl proc_exec_stack_busy_v1937'):b.index('; Release exactly this stack record')]
base+='\n.bss\n.globl proc_exec_resv_head_v1933\nproc_exec_resv_head_v1933: .block 1\n'
(work/'base.s').write_text(base)
for name,old,new in [
 ('unsafe-finish','        pushj   17,proc_exec_stack_busy_v1937\n        jumpn   1,proc_finish_fail','        setz    1,'),
 ('unsafe-discard','        pushj   17,proc_exec_stack_busy_v1937\n        jumpn   1,proc_discard_fail','        setz    1,'),
 ('unsafe-mm','        pushj   17,proc_exec_stack_busy_v1937\n        move    5,1','        setz    1,\n        move    5,1'),
 ('unsafe-fatal','        pushj   17,proc_exec_stack_busy_v1937\n        jumpn   1,proc_event_fatal_other_defer_term_v926','        setz    1,'),
 ('unsafe-exit','        pushj   17,proc_exec_stack_busy_v1937\n        jumpn   1,proc_swap_storage_invariant_v30','        setz    1,'),
 ('unsafe-head-only','proc_exec_stack_next_v1937:\n        move    6,(6)','proc_exec_stack_next_v1937:\n        setz    6,')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
PY
for variant in base unsafe-finish unsafe-discard unsafe-mm unsafe-fatal unsafe-exit unsafe-head-only; do
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-stack-$variant-v1937" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1937.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
