#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-exec-handover-v1934.XXXXXX")
trap 'echo "v1934 native evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel/proc" "$work" <<'PY'
from pathlib import Path
import sys
src,work=map(Path,sys.argv[1:])
s=(src/'exec_lowmem_pdp6.s').read_text()
l=(src/'exec_load.s').read_text()
b=(src/'proc_pure_backing_pdp6.s').read_text()
prefix=''' .text
.globl exec_replace_current
.globl proc_swap_unpack_backing
.equ PROC_USER_MAP_BIT,2
.equ PROC_FDCTL_OFFSET,024
.equ PROC_CRED_OFFSET,066
.equ PROC_SWAP_BACKING_OFFSET,0406
.equ PROC_BRK_OFFSET,0407
.equ EXEC_LOAD_RT_REQUIRED,1
.equ EXEC_LOAD_NOMEM,-2
.equ PROC_SWAP_MOUNT_SHIFT,022
.equ PROC_SWAP_TEXT_SHIFT,026
.equ PROC_SWAP_TEXT_MASK,037777
'''
base=prefix+s[s.index('        .equ    EXEC_R_SAVE_FIRST'):s.index('/**',s.index('        .equ    EXEC_R_FRAME'))]+s[s.index('exec_replace_current:'):s.index('        ; Frame offsets relative to the fully advanced AC17.')]+l[l.index('sixbit_record_words:'):l.index('/**',l.index('sixbit_record_words:'))]+b[b.index('proc_swap_unpack_backing:'):b.index('/*',b.index('proc_swap_unpack_backing_bad:'))]+b[b.index('; Transient executable backing reservation.'):]
(work/'base.s').write_text(base)
for name,old,new in [
 ('unsafe-old','        pushj   17,proc_exec_hold_v1934\n        jumpn   1,exec_replace_invalid','        setz    1,\n        jumpn   1,exec_replace_invalid'),
 ('unsafe-new','        pushj   17,proc_exec_hold_v1934\n        ; A successful attachment','        setz    1,\n        ; A successful attachment'),
 ('unsafe-release','        movei   1,EXEC_R_NEW_HOLD-1(17)\n        pushj   17,proc_exec_release_v1933','        movei   1,EXEC_R_NEW_HOLD-1(17)')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
PY
for variant in base unsafe-old unsafe-new unsafe-release; do
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-exec-$variant-v1934" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1934.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
