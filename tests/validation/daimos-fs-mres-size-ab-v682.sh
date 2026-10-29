#!/bin/sh
# Compare linked PDP-6 provider gateway sizes without editing production.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-fs-size-ab-v682.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s[s.index('fs_provider_reg_call:'):s.index('; KCORE memory-pressure bridge')]
a='        hrrz    7,fs_memfs_service_jump(7)\n        jrst    (7)'
b=('        hrrz    7,fs_memfs_service_jump(7)\n'
   '        ; The missing-service trampoline already returns -1 normally.\n'
   '        ; Invoke it under the same lease and use the common unlock path.\n'
   '        pushj   17,(7)')
assert s.count(a)==1 and s.count(b)==1
header='.text\n.globl fs_provider_reg_call\n'
stubs='''
.globl fs_mres_no_service
fs_mres_no_service: popj 17,
.globl proc_wait_event
proc_wait_event: popj 17,
.globl proc_wakeup_event
proc_wakeup_event: popj 17,
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl fs_provider_ready
fs_provider_ready: .word 1
'''
out=Path(sys.argv[2]); (out/'baseline.s').write_text(header+s+stubs)
(out/'candidate.s').write_text(header+s.replace(a,'        jrst    @fs_memfs_service_jump(7)').replace(b,'        pushj   17,@fs_memfs_service_jump(7)')+stubs)
PY
for variant in baseline candidate; do
  das -F -C -O "$work/$variant.dobj" "$work/$variant.s"
  dlink -b 01000 -o "$work/$variant.dxr" -M "$work/$variant.map" "$work/$variant.dobj"
  pdp10-dec-none-objdump -h "$work/$variant.dobj" > "$work/$variant.header"
done
python3 - "$work/baseline.header" "$work/candidate.header" <<'PY'
import re,sys
counts=[]
for p in sys.argv[1:]:
 s=open(p).read()
 m=re.search(r'text=(\d+) data=(\d+) bss=(\d+)',s)
 assert m,s
 counts.append(tuple(map(int,m.groups())))
base,new=counts
assert base[0]-new[0]==2,(base,new)
assert base[1:]==new[1:],(base,new)
print('v682 linked provider gateway (text/data/bss words):',base,'->',new)
print('v682: net text saving = 2 words, no new data/bss: PASS')
PY
