#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
work=$TMPDIR/d6fsck-mutation-recovery-v1-$$
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/base"

cat > "$work/payload.words" <<'EOT'
0444141515557
000001000000
000000000000
EOT
python3 - "$work/data.words" <<'PY'
import sys
with open(sys.argv[1], 'w') as f:
    for i in range(300):
        f.write('%012o\n' % ((0o123456700000 + i) & ((1 << 36) - 1)))
PY

./mkdsk -n 1 -m clean -p "$work/payload.words" -o "$work/base" \
    --d6fs-layout --logstore-blocks 4 --badmap-blocks 1 \
    --swap-tail-blocks 2 --member-sectors 02000 >/dev/null
./mkd6fs -n 1 -d "$work/base" \
    -f /SYSTEM/A:"$work/data.words":0644:words >/dev/null
./d6fsck -n 1 -d "$work/base" >/dev/null 2>&1

# Remove /SYSTEM/A's directory reference.  With this formatter fixture the
# FCBs are ROOT=0, SYSTEM=1, A=2.  Locate SYSTEM's data extent from its FCB
# rather than assuming a data-block number.
mutate()
{
        image=$1
        mode=$2
        python3 - "$image" "$mode" <<'PY'
import struct, sys
P=sys.argv[1]
mode=sys.argv[2]
MASK=(1<<36)-1
BW=128
FW=16

def rdw(f, sector, word):
    f.seek((sector*BW+word)*8)
    return struct.unpack('<Q',f.read(8))[0]&MASK

def wrw(f, sector, word, value):
    f.seek((sector*BW+word)*8)
    f.write(struct.pack('<Q',value&MASK))

def fcb_word(f, base, fcb_start, index, word):
    off=index*FW+word
    return rdw(f,base+fcb_start+off//BW,off%BW)

def set_fcb_word(f, base, fcb_start, index, word, value):
    off=index*FW+word
    wrw(f,base+fcb_start+off//BW,off%BW,value)

with open(P,'r+b') as f:
    desc=[rdw(f,0,i) for i in range(0o20)]
    base=(desc[0o7]>>18)&0o777777
    sa=desc[0o10]; sb=desc[0o11]
    a=[rdw(f,base+sa,i) for i in range(0o20)]
    b=[rdw(f,base+sb,i) for i in range(0o20)]
    super=a if a[1] >= b[1] else b
    fcb_start=super[0o11]

    # SYSTEM is FCB 1.  Its first extent contains its directory entry for A.
    run=fcb_word(f,base,fcb_start,1,0o6)
    dstart=run>>12
    for wi in range(6):
        wrw(f,base+dstart,wi,0)

    if mode == 'orphan':
        # Crash after old namespace removal but before FCB reclamation, as can
        # happen during cross-directory rename/unlink.  FCB 2 and its extents
        # remain intact and uniquely owned.
        pass
    elif mode == 'leak':
        # Crash after the FCB has been cleared but before its extent allocation
        # bits are released.  The free map therefore contains leaked blocks.
        for wi in range(FW):
            set_fcb_word(f,base,fcb_start,2,wi,0)
    else:
        raise SystemExit('bad mode')
PY
}

mkdir -p "$work/orphan"
cp "$work/base/dsk0.dsk" "$work/orphan/dsk0.dsk"
mutate "$work/orphan/dsk0.dsk" orphan
if ./d6fsck -n 1 -d "$work/orphan" >"$work/orphan.check" 2>&1; then
        echo 'd6fsck accepted crash-orphaned FCB' >&2
        exit 1
fi
grep -q 'unreachable FCB' "$work/orphan.check"
./d6fsck -r -n 1 -d "$work/orphan" >"$work/orphan.repair" 2>&1
./d6fsck -n 1 -d "$work/orphan" >"$work/orphan.final" 2>&1
grep -q 'clean$' "$work/orphan.final"

mkdir -p "$work/leak"
cp "$work/base/dsk0.dsk" "$work/leak/dsk0.dsk"
mutate "$work/leak/dsk0.dsk" leak
if ./d6fsck -n 1 -d "$work/leak" >"$work/leak.check" 2>&1; then
        echo 'd6fsck accepted crash-leaked allocation' >&2
        exit 1
fi
grep -q 'allocated leaked block' "$work/leak.check"
./d6fsck -r -n 1 -d "$work/leak" >"$work/leak.repair" 2>&1
./d6fsck -n 1 -d "$work/leak" >"$work/leak.final" 2>&1
grep -q 'clean$' "$work/leak.final"

printf '%s\n' 'd6fsck-mutation-recovery-v1 PASS'
