#!/bin/sh
# Independently format equal-layout media and verify both A/B UUID pairs.
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/d6fs-format-identity-v1927.XXXXXX")
trap 'echo "v1927 formatter evidence: $work"' EXIT
make -s -C "$DAIMOS_REPO/tools/host" BUILD="$work" "$work/mkd6fs" "$work/mkdsk" "$work/d6fsck"
printf '0\n' > "$work/boot.words"
for d in a b; do
    mkdir -p "$work/$d"
    "$work/mkdsk" -n 1 -m clean -p "$work/boot.words" -o "$work/$d" --d6fs-layout --logstore-blocks 0 --swap-tail-blocks 0
    "$work/mkd6fs" -n 1 -d "$work/$d" -D /SYSTEM:0755
 done
python3 - "$work" <<'PY'
from pathlib import Path
import struct, sys
work=Path(sys.argv[1])
ids=[]
for name in ('a','b'):
    data=(work/name/'dsk0.dsk').read_bytes()
    words=struct.unpack('<%dQ'%(len(data)//8),data)
    copies=[words[i:i+16] for i in range(0,len(words),128) if words[i]==0o44066263602]
    assert len(copies)==2 and copies[0]==copies[1]
    ids.append(copies[0][3:5])
assert ids[0]!=ids[1] and all(any(pair) for pair in ids)
assert all(0<=word<(1<<36) for pair in ids for word in pair)
print('PASS equal-layout independent D6FS volume identities, matching A/B copies')
PY
