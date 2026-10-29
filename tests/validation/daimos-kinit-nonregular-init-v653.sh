#!/bin/sh
# An otherwise valid D6FS root must reject /SYSTEM/INIT if nonregular.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mode=${1:-nonregular}
case "$mode" in nonregular|missing) ;; *) echo 'usage: test [nonregular|missing]' >&2; exit 2;; esac
work=$(mktemp -d "$TMPDIR/daimos-init-type-v653.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v653 diagnostics: $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_INIT_TYPE_BUILD_V653:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
  BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=gcc \
  BOOT_CORE_WORDS=0300000 SIMH_CPU_KWORDS=96 > "$work/build.log" 2>&1 || {
  tail -25 "$work/build.log" >&2; exit 1;
}
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/preflight.log" 2>&1 || {
  cat "$work/preflight.log" >&2; exit 1;
}
cp -a "$build/disk" "$work/disk"
python3 - "$work/disk" "$mode" <<'PY'
import os, struct, sys
p=sys.argv[1]
mode=sys.argv[2]
def phys(m,s):
    with open(os.path.join(p,'dsk%d.dsk'%m),'rb') as f:
        f.seek(s*1024)
        return struct.unpack('<128Q',f.read(1024))
head=phys(0,0)
assert head[6]==0o442654636222
base=head[7]>>18
def logical(n): return phys(n%4,base+n//4)
sb=logical(head[8]); fcb_base=sb[9]
assert sb[2]==0 and sb[8]==0
def fcb(i): return logical(fcb_base+i//8)[(i%8)*16:(i%8+1)*16]
def entry(parent,wanted):
    f=fcb(parent)
    assert f[0]>>33==2 and f[2]%6==0
    words=[]
    for i in range((f[2]+127)//128): words.extend(logical((f[6]>>12)+i))
    matches=[]
    for j in range(0,f[2],6):
        word=words[j]
        name=''.join(chr(32+((word>>(30-6*k))&63)) for k in range(6)).rstrip()
        if name==wanted: matches.append((words[j+5]>>18, (f[6]>>12)+j//128, j%128))
    assert len(matches)==1,(wanted,matches)
    return matches[0]
system,_,_=entry(0,'SYSTEM')
index,dirblock,diroff=entry(system,'INIT')
block=fcb_base+index//8
word=(index%8)*16
current=logical(block)[word]
assert current>>33==1,(index,oct(current))
if mode=='nonregular':
    # Make the actual file FCB a directory, leaving root metadata intact.
    targetblock, targetword=block,word
    value=(current & ((1<<33)-1)) | (2<<33)
else:
    # Clear the directory-entry child reference; lookup must report absent.
    targetblock,targetword=dirblock,diroff+5
    assert (logical(targetblock)[targetword]>>18)==index
    value=0
with open(os.path.join(p,'dsk%d.dsk'%(targetblock%4)),'r+b') as f:
    f.seek(((base+targetblock//4)*128+targetword)*8)
    f.write(struct.pack('<Q',value))
print('v653:',mode,'/SYSTEM/INIT FCB',index)
PY
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
  "$build/boot.ini" "$work/headless.ini" 32863 46863
sed -e "s|$build/disk/|$work/disk/|g" "$work/headless.ini" > "$work/failure.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 45s "$PDP10_PREFIX/bin/pdp6" \
  "$work/failure.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -45 "$work/boot.log" >&2; exit 1; }
grep -Fq '?RT' "$work/boot.log"
grep -q 'HALT instruction' "$work/boot.log"
grep -Eq 'D6FS[[:space:]]+LOADED' "$work/boot.log"
if grep -Fq 'INIT V1' "$work/boot.log"; then
  echo 'v653 booted nonregular INIT' >&2; exit 1
fi
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/postflight.log" 2>&1 || {
  echo 'v653 changed original diskset' >&2; exit 1;
}
passed=1
echo "daimos-kinit-nonregular-init-v653: PASS (D6FS mounts, $mode INIT rejected)"
