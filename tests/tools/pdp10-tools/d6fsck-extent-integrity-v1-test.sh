#!/bin/sh
set -eu
: "${TMPDIR:?TMPDIR must be set}"
work=$TMPDIR/d6fsck-extent-integrity-v1-$$
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/disks"
cat > "$work/payload.words" <<'EOT'
0444141515557
000001000000
000000000000
EOT
python3 - "$work/data.words" <<'PY'
import sys
with open(sys.argv[1], 'w') as f:
    for i in range(300):
        f.write('%012o\n' % ((0o234567000000 + i) & ((1 << 36) - 1)))
PY
./mkdsk -n 1 -m clean -p "$work/payload.words" -o "$work/disks" \
    --d6fs-layout --logstore-blocks 4 --badmap-blocks 1 \
    --swap-tail-blocks 2 --member-sectors 02000 >/dev/null
./mkd6fs -n 1 -d "$work/disks" \
    -f /SYSTEM/A:"$work/data.words":0644:words >/dev/null
python3 - "$work/disks/dsk0.dsk" <<'PY'
import struct, sys
P=sys.argv[1]
MASK=(1<<36)-1
BW=128
FW=16

def rdw(f, sector, word):
    f.seek((sector*BW+word)*8)
    return struct.unpack('<Q',f.read(8))[0]&MASK

def wrw(f, sector, word, value):
    f.seek((sector*BW+word)*8)
    f.write(struct.pack('<Q',value&MASK))

with open(P,'r+b') as f:
    desc=[rdw(f,0,i) for i in range(0o20)]
    base=(desc[0o7]>>18)&0o777777
    sa=desc[0o10]; sb=desc[0o11]
    a=[rdw(f,base+sa,i) for i in range(0o20)]
    b=[rdw(f,base+sb,i) for i in range(0o20)]
    sup=a if a[1] >= b[1] else b
    fs=sup[0o11]
    idx=2
    off=idx*FW
    sec=base+fs+off//BW
    pos=off%BW
    meta=rdw(f,sec,pos+0)
    run0=rdw(f,sec,pos+0o6)
    start=run0>>12
    # Claim two extents and make the second overlap the first block.
    meta=(meta & ~(0o17<<4)) | (2<<4)
    wrw(f,sec,pos+0,meta)
    wrw(f,sec,pos+0o7,(start<<12)|0)
PY
if ./d6fsck -n 1 -d "$work/disks" >"$work/check.out" 2>&1; then
    echo 'd6fsck accepted internally overlapping FCB extents' >&2
    exit 1
fi
grep -q 'invalid FCB' "$work/check.out"
printf '%s\n' 'd6fsck-extent-integrity-v1 PASS'
