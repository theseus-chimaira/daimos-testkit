#!/bin/sh
set -eu
: "${TMPDIR:?TMPDIR must be set}"
work=$TMPDIR/d6-maintenance-v2-$$
trap 'rm -rf "$work"' 0 1 2 3 15
mkdir -p "$work/disks"
cat > "$work/payload.words" <<'EOT'
0444141515557
000001000000
000000000000
EOT
cat > "$work/init.words" <<'EOT'
012345670123
076543210765
EOT
./mkdsk -n 3 -m clean -p "$work/payload.words" -o "$work/disks" \
    --d6fs-layout --logstore-blocks 4 --badmap-blocks 1 \
    --spare-blocks 4 --swap-tail-blocks 2 --member-sectors 02000,01400,01000 >/dev/null
./mkd6fs -n 3 -d "$work/disks" \
    -f /SYSTEM/INIT:"$work/init.words":0755:words >/dev/null
./d6swap -n 3 -d "$work/disks" --show >"$work/reservation-initial.out"
grep -q 'reservation=[0-7][0-7]*+6 logstore=1+4' "$work/reservation-initial.out"
# BADMAP is a stable physical source->spare exception map.  Remapping an
# allocated filesystem sector is safe because d6bad first copies its complete
# contents to a reserved spare, then publishes the exception atomically.
./d6bad -n 3 -d "$work/disks" --add 0:0700:2 >"$work/bad.out" 2>&1
./d6bad -n 3 -d "$work/disks" --list >>"$work/bad.out"
grep -q 'source=0:700 spare=0:' "$work/bad.out"
grep -q 'source=0:701 spare=0:' "$work/bad.out"
python3 - "$work/disks/dsk0.dsk" <<'PYBAD'
import struct, sys
path=sys.argv[1]
with open(path,'r+b') as f:
    for sec in (0o700,0o701):
        f.seek(sec*128*8)
        f.write(b'\0'*(128*8))
PYBAD
./d6fsck -n 3 -d "$work/disks" >"$work/bad-fsck.out" 2>&1
grep -q 'clean$' "$work/bad-fsck.out"
./logstore -n 3 -d "$work/disks" --init >/dev/null
./logstore -n 3 -d "$work/disks" --append -s 3 -S 0123 -t 1234 -p 0777 >/dev/null
./logstore -n 3 -d "$work/disks" --append -s 5 -S 0456 -t 5678 -p 01234 -p 05670 >/dev/null
# Logical logstore block 0 is logical block 1.  In a three-member INTERLEAVE
# root that is member 1, physical base sector 1.  Destroying the source after
# publication proves logstore reads honor BADMAP too.
./d6bad -n 3 -d "$work/disks" --add 1:01 >/dev/null
python3 - "$work/disks/dsk1.dsk" <<'PYLOG'
import sys
with open(sys.argv[1],'r+b') as f:
    f.seek(1*128*8)
    f.write(b'\0'*(128*8))
PYLOG
./logstore -n 3 -d "$work/disks" --dump >"$work/log.out"
grep -q 'seq=1 ' "$work/log.out"
grep -q 'seq=2 ' "$work/log.out"
cp -R "$work/disks" "$work/prepack-source"
./packfs -n 3 -d "$work/disks" --output "$work/packed" >/dev/null
./d6fsck -n 3 -d "$work/disks" >"$work/fsck-prepack-source.out" 2>&1
grep -q 'clean$' "$work/fsck-prepack-source.out"
./d6fsck -n 3 -d "$work/packed" >"$work/fsck-packed.out" 2>&1
grep -q 'clean$' "$work/fsck-packed.out"
./d6swap -n 3 -d "$work/packed" --show >"$work/reservation-packed.out"
grep -q 'reservation=[0-7][0-7]*+6 logstore=1+4' "$work/reservation-packed.out"
for m in 0 1 2; do
        cmp "$work/prepack-source/dsk$m.dsk" "$work/disks/dsk$m.dsk"
done
./d6swap -n 3 -d "$work/disks" --plan --ram-words 040000 >"$work/swap-plan.out"
grep -q 'policy=1x-RAM' "$work/swap-plan.out"
# Seed each logical swap block with a distinct value.  The resize must preserve
# the old logical prefix even though the physical tail starts move.
python3 - "$work/disks" write <<'PYSWAP'
import os, struct, sys
path,mode=sys.argv[1],sys.argv[2]
BW=128; MAGIC=0o442654636222; MASK=(1<<36)-1
fps=[open(os.path.join(path,'dsk%d.dsk'%i),'r+b') for i in range(3)]
def rd(f,s,w): f.seek((s*BW+w)*8); return struct.unpack('<Q',f.read(8))[0]&MASK
def wr(f,s,w,v): f.seek((s*BW+w)*8); f.write(struct.pack('<Q',v&MASK))
m=[]; tail=None
for f in fps:
    for sec in range(0o200):
        if rd(f,sec,0o6)==MAGIC:
            d=[rd(f,sec,i) for i in range(0o20)]
            m.append(((d[0o7]>>18)&0o777777,d[0o7]&0o777777))
            tail=d[0o12] if tail is None else tail
            break
def raw_swap(l):
    mi=l%len(m)
    rel=l//len(m)
    return mi,os.path.getsize(os.path.join(path,'dsk%d.dsk'%mi))//(BW*8)-tail+rel
for l in range(tail*len(m)):
    mi,sec=raw_swap(l)
    wr(fps[mi],sec,0,0o700000+l)
for f in fps: f.close()
PYSWAP
./d6swap -n 3 -d "$work/disks" --resize-tail 3 --output "$work/resized" >"$work/swap-resize.out" 2>&1
python3 - "$work/resized" <<'PYSWAPCHECK'
import os, struct, sys
path=sys.argv[1]; BW=128; MAGIC=0o442654636222; MASK=(1<<36)-1
fps=[open(os.path.join(path,'dsk%d.dsk'%i),'rb') for i in range(3)]
def rd(f,s,w): f.seek((s*BW+w)*8); return struct.unpack('<Q',f.read(8))[0]&MASK
m=[]; tail=None
for f in fps:
    for sec in range(0o200):
        if rd(f,sec,0o6)==MAGIC:
            d=[rd(f,sec,i) for i in range(0o20)]
            m.append(((d[0o7]>>18)&0o777777,d[0o7]&0o777777))
            tail=d[0o12] if tail is None else tail
            break
def raw_swap(l):
    mi=l%len(m)
    rel=l//len(m)
    return mi,os.path.getsize(os.path.join(path,'dsk%d.dsk'%mi))//(BW*8)-tail+rel
for l in range(tail*len(m)):
    mi,sec=raw_swap(l); v=rd(fps[mi],sec,0)
    want=(0o700000+l) if l<6 else 0
    if v!=want: raise SystemExit('swap content mismatch %o: %o != %o'%(l,v,want))
for f in fps: f.close()
PYSWAPCHECK
./d6swap -n 3 -d "$work/disks" --show >"$work/swap-source.out"
grep -q 'tail-blocks/member=2' "$work/swap-source.out"
./d6swap -n 3 -d "$work/resized" --show >"$work/swap-show.out"
grep -q 'tail-blocks/member=3' "$work/swap-show.out"
grep -q 'reservation=[0-7][0-7]*+11 logstore=1+4' "$work/swap-show.out"
./d6fsck -n 3 -d "$work/disks" >"$work/fsck-source.out" 2>&1
grep -q 'clean$' "$work/fsck-source.out"
./d6fsck -n 3 -d "$work/resized" >"$work/fsck.out" 2>&1
grep -q 'clean$' "$work/fsck.out"

# Legacy V2 media may have a real DBOOT swap tail but zero D6FS swap fields.
# Zero only the swap reservation in both A/B copies, preserving logstore.
cp -R "$work/disks" "$work/legacy"
python3 - "$work/legacy" <<'PYLEGACY'
import os, struct, sys
path=sys.argv[1]
BW=128
MAGIC=0o442654636222
MASK=(1<<36)-1
fps=[open(os.path.join(path,'dsk%d.dsk'%i),'r+b') for i in range(3)]
def rd(f,sec,w):
    f.seek((sec*BW+w)*8); return struct.unpack('<Q',f.read(8))[0]&MASK
def wr(f,sec,w,v):
    f.seek((sec*BW+w)*8); f.write(struct.pack('<Q',v&MASK))
members=[]; desc=None
for f in fps:
    for sec in range(0o200):
        if rd(f,sec,0o6)==MAGIC:
            words=[rd(f,sec,i) for i in range(0o20)]
            members.append(((words[0o7]>>18)&0o777777,words[0o7]&0o777777))
            if desc is None: desc=words
            break
def mapblock(lbn):
    floor=0
    while True:
        active=[i for i,(_,blocks) in enumerate(members) if blocks>floor]
        nxt=min(members[i][1] for i in active)
        zone=(nxt-floor)*len(active)
        if lbn<zone:
            mi=active[lbn%len(active)]
            return mi,members[mi][0]+floor+lbn//len(active)
        lbn-=zone; floor=nxt
for lbn in (desc[0o10],desc[0o11]):
    mi,sec=mapblock(lbn)
    wr(fps[mi],sec,0o5,0)
    high=rd(fps[mi],sec,0o17)
    wr(fps[mi],sec,0o17,high & 0o000077770000)
for f in fps: f.close()
PYLEGACY
./d6fsck -n 3 -d "$work/legacy" >"$work/legacy-pre.out" 2>&1
./d6swap -n 3 -d "$work/legacy" --migrate-reservation >"$work/migrate.out" 2>&1
./d6swap -n 3 -d "$work/legacy" --show >"$work/legacy-show.out"
grep -q 'reservation=[0-7][0-7]*+6 logstore=1+4' "$work/legacy-show.out"
./d6fsck -n 3 -d "$work/legacy" >"$work/legacy-post.out" 2>&1
grep -q 'clean$' "$work/legacy-post.out"

echo 'd6-maintenance-v2 PASS'
