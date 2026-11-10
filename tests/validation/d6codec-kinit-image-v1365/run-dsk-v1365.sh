#!/bin/sh
# Real DSK270 DBOOT Stage1 with isolated grouped KINIT disk members.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
work="$TMPDIR/d6codec-kinit-v1365"
src="$work/stage1-generated-v1365/stage1-dsk-v1364.s"
stream="$work/kinit-grouped-v1365.words"
test -s "$src" && test -s "$stream"
dxr="$work/stage1-dsk-v1365.dxr"
paper="$work/stage1-dsk-v1365.pt"
disks="$work/dsk-members-v1365"
das -F -K -O "$dxr" "$src"
dxrconvert --pdp6-readin -b 060 "$dxr" "$paper"
mkdir -p "$disks"
mkdsk -n 4 -m clean -p "$stream" -o "$disks" \
  --member-sectors 0130000,0130000,0130000,0130000
for index in 0 1 2 3; do
    test -s "$disks/dsk$index.dsk"
done
descriptor=$(sed -n '2p' "$stream")
entry_offset=$(printf '%s\n' "$descriptor" | cut -c 7-12)
entry=$(printf '%06o' "$((030000 + 0$entry_offset))")
first=$(sed -n '3p' "$DAIMOS_REPO/build/system/boot/pdp6/kinit.words")
ini="$work/boot-dsk-grouped-v1365.simh"
out="$work/boot-dsk-grouped-v1365.out"
cat > "$ini" <<EOF_SIMH
set cpu 256k
set ptr enabled
set dsk enabled
set dp enabled
deposit 020 710600000060
deposit 021 710740000010
deposit 022 254000000021
deposit 023 710440000026
deposit 024 710740000010
deposit 025 254000000024
deposit 026 000000000000
deposit 027 254000000021
attach -q ptr $paper
deposit ptr time 1
attach -q dsk0 $disks/dsk0.dsk
attach -q dsk1 $disks/dsk1.dsk
attach -q dsk2 $disks/dsk2.dsk
attach -q dsk3 $disks/dsk3.dsk
break $entry
go 020
ex pc
ex 030000
exit
EOF_SIMH
if ! timeout -k 2s 90s "$PDP10_PREFIX/bin/pdp6" "$ini" \
    </dev/null > "$out" 2>&1; then
    tail -75 "$out" >&2
    echo 'v1365: DSK270 grouped Stage-1 failed to reach KINIT entry' >&2
    exit 1
fi
if ! grep -F "Breakpoint, PC: $entry" "$out" >/dev/null || \
   ! grep -F "$first" "$out" >/dev/null; then
    tail -75 "$out" >&2
    echo 'v1365: DSK270 grouped decode/KINIT entry mismatch' >&2
    exit 1
fi
echo "PASS v1365: actual Stage0/DSK270 four-member DBOOT -> grouped Stage1 -> KINIT $entry"
