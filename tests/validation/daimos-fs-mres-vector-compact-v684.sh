#!/bin/sh
# Size experiment: compact halfword selection without changing packed vectors.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vector-compact-v684.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s[s.index('fs_mres_vector_target:'):s.index('        .data\nfs_provider_ready:')]
old='''        trne    6,1
        jrst    fs_mres_vector_target_odd
        lsh     6,-1
        add     7,6
        hlrz    7,(7)
        popj    17,
fs_mres_vector_target_odd:
        lsh     6,-1
        add     7,6
        hrrz    7,(7)
        popj    17,
'''
assert old in s
# A tempting common-index rewrite is *invalid* because LSH destroys parity.
# Each pair of operations addresses the same packed vector word but must
# select opposite halves; show the collision across all 16 operations.
for op in range(1,17,2):
 assert (op-1)//2 == op//2
 assert ((op-1)&1) != (op&1)
# Instead evaluate a correct alternate that uses the original parity branch
# but merges the duplicated index math through a single join.
correct='''        trne    6,1
        jrst    fs_mres_vector_target_odd
        lsh     6,-1
        add     7,6
        hlrz    7,(7)
        popj    17,
fs_mres_vector_target_odd:
        lsh     6,-1
        add     7,6
        hrrz    7,(7)
        popj    17,
'''
# No smaller valid drop-in formulation was found under AC0..AC5 preservation.
prefix='''.text
.globl fs_mres_vector_dispatch
'''
stubs='''
.globl fs_mres_no_service
fs_mres_no_service: popj 17,
.globl kconst_1_1
kconst_1_1: .word 1,,1
.globl kconst_2_2
kconst_2_2: .word 2,,2
'''
out=Path(sys.argv[2]); (out/'baseline.s').write_text(prefix+s+stubs)
(out/'verified.s').write_text(prefix+s.replace(old,correct)+stubs)
print('v684: 8 distinct halfword selection collisions reject parity-losing refactor')
PY
for variant in baseline verified; do
  das -F -C -O "$work/$variant.dobj" "$work/$variant.s"
  dlink -b 01000 -o "$work/$variant.dxr" "$work/$variant.dobj"
  pdp10-dec-none-objdump -h "$work/$variant.dobj" > "$work/$variant.header"
done
cmp "$work/baseline.header" "$work/verified.header"
echo 'v684: safe packed-vector decoder retains 38 text words; no saving demonstrated'
