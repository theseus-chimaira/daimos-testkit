#!/bin/sh
# Isolated linked size accounting for the shared filesystem vector machinery.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vector-cost-v683.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
start=s.index('fs_mres_vector_target:')
end=s.index('        .data\nfs_provider_ready:',start)
body=s[start:end]
stub='''\n.globl fs_mres_no_service\nfs_mres_no_service: popj 17,\n.globl kconst_1_1\nkconst_1_1: .word 1,,1\n.globl kconst_2_2\nkconst_2_2: .word 2,,2\n'''
p=Path(sys.argv[2])
(p/'vector.s').write_text('.text\n.globl fs_mres_vector_dispatch\n'+body+stub)
(p/'stub.s').write_text('.text\n.globl fs_mres_vector_dispatch\nfs_mres_vector_dispatch: popj 17,\n.globl fs_mres_context_vector_dispatch\nfs_mres_context_vector_dispatch: popj 17,\n'+stub)
PY
for variant in vector stub; do
    das -F -C -O "$work/$variant.dobj" "$work/$variant.s"
    dlink -b 01000 -o "$work/$variant.dxr" -M "$work/$variant.map" "$work/$variant.dobj"
    pdp10-dec-none-objdump -h "$work/$variant.dobj" > "$work/$variant.header"
done
python3 - "$work/vector.header" "$work/stub.header" <<'PY'
import re,sys
counts=[]
for file in sys.argv[1:]:
 m=re.search(r'text=(\d+) data=(\d+) bss=(\d+)',open(file).read())
 assert m,file
 counts.append(tuple(map(int,m.groups())))
full,stub=counts
assert full[0]>stub[0]
print('v683 linked full vectors:',full,'minimal direct-entry stubs:',stub)
print('v683 gross code removable:',full[0]-stub[0],'words; excludes per-operation bindings and locking')
PY
python3 - "$DAIMOS_REPO/system/kernel/fs" <<'PY'
from pathlib import Path
import sys,re
root=Path(sys.argv[1]); total=0
for name,label in [('d6fs_runtime.s','d6fs_mres_vector'),('memfs_runtime.s','memfs_mres_vector'),('dtfs_runtime.s','dtfs_mres_vector'),('tsfs_runtime.s','tsfs_mres_vector')]:
 text=(root/name).read_text().split(label+':',1)[1].split('        .text',1)[0]
 entries=[]
 for pair in re.findall(r'^\s*\.word\s+([^\n;]+)',text,re.M):
  entries.extend(x.strip() for x in pair.split(',,')[:2])
 assert len(entries)==16,(name,len(entries))
 used=sum(x!='0' for x in entries)
 total+=used
 print('v683',label,':',used,'nonzero operations of 16; 8 packed vector words')
print('v683 direct operation targets across four providers:',total,'(before sharing/alias reduction)')
PY
