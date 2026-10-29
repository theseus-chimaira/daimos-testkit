#!/bin/sh
# Link-size feasibility: real instruction-embedded per-operation direct slots.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-direct-bind-v685.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/fs" "$work" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1]);out=Path(sys.argv[2]);vectors=[]
for name,label in [('d6fs_runtime.s','d6fs_mres_vector'),('memfs_runtime.s','memfs_mres_vector'),('dtfs_runtime.s','dtfs_mres_vector'),('tsfs_runtime.s','tsfs_mres_vector')]:
 t=(root/name).read_text().split(label+':',1)[1].split('        .text',1)[0]
 pairs=re.findall(r'^\s*\.word\s+([^\n;]+)',t,re.M)
 targets=[v.strip() for p in pairs for v in p.split(',,')]
 assert len(targets)==16
 vectors.append((label,targets))
# Compare same four provider tables, preserving unsupported-operation slots.
# Use local placeholder targets for a standalone link; target names are
# intentionally retained as comments to audit the real source mapping.
base=['.text','.globl test_entry','test_entry: popj 17,','.data']
direct=['.text','.globl test_entry','test_entry: popj 17,','.data']
for label,ts in vectors:
 base.append(label+':')
 direct.append(label+'_direct:')
 for i in range(0,16,2):
  base.append(' .word '+('test_entry' if ts[i]!='0' else '0')+',,'+('test_entry' if ts[i+1]!='0' else '0'))
 for i,t in enumerate(ts):
  direct.append(' jrst '+('test_entry' if t!='0' else '0')+' ; '+label+' '+str(i+1)+' '+t)
(out/'packed.s').write_text('\n'.join(base)+'\n')
(out/'direct.s').write_text('\n'.join(direct)+'\n')
print('v685: generated 4 real 16-operation tables, with missing slots retained')
PY
for v in packed direct; do
 das -F -C -O "$work/$v.dobj" "$work/$v.s"
 dlink -b 01000 -o "$work/$v.dxr" "$work/$v.dobj"
 pdp10-dec-none-objdump -h "$work/$v.dobj" > "$work/$v.header"
done
python3 - "$work/packed.header" "$work/direct.header" <<'PY'
import re,sys
vals=[]
for p in sys.argv[1:]:
 m=re.search(r'text=(\d+) data=(\d+) bss=(\d+)',open(p).read());assert m
 vals.append(tuple(int(x) for x in m.groups()))
packed,direct=vals
assert direct[1]-packed[1]==32,(packed,direct)
print('v685 packed: ',packed,'direct instruction-embedded:',direct)
print('v685 direct tables add 32 words before removing shared decoder')
PY
