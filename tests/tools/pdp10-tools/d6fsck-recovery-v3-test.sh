#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
work=$TMPDIR/d6fsck-recovery-v3-$$
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/base"

cat > "$work/payload.words" <<'EOT'
0444141515557
000001000000
000000000000
EOT
cat > "$work/init.words" <<'EOT'
012345670123
076543210765
EOT

./mkdsk -n 1 -m clean -p "$work/payload.words" -o "$work/base" \
    --d6fs-layout --logstore-blocks 4 --badmap-blocks 1 \
    --swap-tail-blocks 2 --member-sectors 02000 >/dev/null
./mkd6fs -n 1 -d "$work/base" \
    -f /SYSTEM/INIT:"$work/init.words":0755:words >/dev/null
./d6fsck -n 1 -d "$work/base" >/dev/null 2>&1

# mode=dirty: publish a newer structurally valid DIRTY generation.
# mode=torn-dirty: damage the alternate copy before metadata can be touched;
#                  the surviving older CLEAN generation remains safe.
# mode=torn-clean: leave a valid newer DIRTY generation and damage the
#                  attempted still-newer CLEAN publication.
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
SW=16

def rdw(f, sector, word):
    f.seek((sector*BW+word)*8)
    return struct.unpack('<Q',f.read(8))[0]&MASK

def wrw(f, sector, word, value):
    f.seek((sector*BW+word)*8)
    f.write(struct.pack('<Q',value&MASK))

def read_super(f, sector):
    return [rdw(f,sector,i) for i in range(SW)]

def write_super(f, sector, words):
    for i,v in enumerate(words):
        wrw(f,sector,i,v)

with open(P,'r+b') as f:
    desc=[rdw(f,0,i) for i in range(0o20)]
    base=(desc[0o7]>>18)&0o777777
    sa=desc[0o10]; sb=desc[0o11]
    a=read_super(f,base+sa); b=read_super(f,base+sb)
    if a[1] >= b[1]:
        selected,other=sa,sb
        cur=a
    else:
        selected,other=sb,sa
        cur=b

    if mode == 'dirty':
        nxt=list(cur)
        nxt[1]=(cur[1]+1)&MASK
        nxt[2]=1
        write_super(f,base+other,nxt)
    elif mode == 'torn-dirty':
        # Simulate failure while publishing the first DIRTY generation.  Make
        # the target structurally invalid, leaving the selected CLEAN copy.
        nxt=list(cur)
        nxt[1]=(cur[1]+1)&MASK
        nxt[2]=1
        nxt[0]=0
        write_super(f,base+other,nxt)
    elif mode == 'torn-clean':
        dirty=list(cur)
        dirty[1]=(cur[1]+1)&MASK
        dirty[2]=1
        write_super(f,base+other,dirty)
        clean_target=selected
        torn=list(dirty)
        torn[1]=(dirty[1]+1)&MASK
        torn[2]=0
        torn[0]=0
        write_super(f,base+clean_target,torn)
    else:
        raise SystemExit('bad mode')
PY
}

# A newer DIRTY generation is never clean media.  Read-only d6fsck must fail;
# repair mode performs the full scan and publishes a newer CLEAN generation.
mkdir -p "$work/dirty"
cp "$work/base/dsk0.dsk" "$work/dirty/dsk0.dsk"
mutate "$work/dirty/dsk0.dsk" dirty
if ./d6fsck -n 1 -d "$work/dirty" >"$work/dirty.check" 2>&1; then
        echo 'd6fsck accepted selected DIRTY generation' >&2
        exit 1
fi
grep -q 'selected superblock DIRTY' "$work/dirty.check"
./d6fsck -r -n 1 -d "$work/dirty" >"$work/dirty.repair" 2>&1
./d6fsck -n 1 -d "$work/dirty" >"$work/dirty.final" 2>&1
grep -q 'clean$' "$work/dirty.final"

# If the initial DIRTY publication tears before becoming structurally valid,
# metadata has not begun changing.  The surviving CLEAN copy remains usable;
# fsck repair merely restores redundancy.
mkdir -p "$work/torn-dirty"
cp "$work/base/dsk0.dsk" "$work/torn-dirty/dsk0.dsk"
mutate "$work/torn-dirty/dsk0.dsk" torn-dirty
if ./d6fsck -n 1 -d "$work/torn-dirty" >"$work/torn-dirty.check" 2>&1; then
        echo 'd6fsck did not report torn DIRTY superblock copy' >&2
        exit 1
fi
grep -q 'invalid superblock' "$work/torn-dirty.check"
grep -q 'state=CLEAN' "$work/torn-dirty.check"
./d6fsck -r -n 1 -d "$work/torn-dirty" >/dev/null 2>&1
./d6fsck -n 1 -d "$work/torn-dirty" >"$work/torn-dirty.final" 2>&1
grep -q 'clean$' "$work/torn-dirty.final"

# If CLEAN publication tears after metadata writes, the older valid generation
# is DIRTY.  It must remain a recovery-required image until fsck completes a
# full scan and publishes CLEAN again.
mkdir -p "$work/torn-clean"
cp "$work/base/dsk0.dsk" "$work/torn-clean/dsk0.dsk"
mutate "$work/torn-clean/dsk0.dsk" torn-clean
if ./d6fsck -n 1 -d "$work/torn-clean" >"$work/torn-clean.check" 2>&1; then
        echo 'd6fsck accepted torn CLEAN publication over DIRTY generation' >&2
        exit 1
fi
grep -q 'invalid superblock' "$work/torn-clean.check"
grep -q 'selected superblock DIRTY' "$work/torn-clean.check"
./d6fsck -r -n 1 -d "$work/torn-clean" >"$work/torn-clean.repair" 2>&1
./d6fsck -n 1 -d "$work/torn-clean" >"$work/torn-clean.final" 2>&1
grep -q 'clean$' "$work/torn-clean.final"

printf '%s\n' 'd6fsck-recovery-v3 PASS'
