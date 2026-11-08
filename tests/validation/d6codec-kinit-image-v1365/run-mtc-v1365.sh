#!/bin/sh
# Run after run-dtc-v1365.sh has prepared the isolated grouped stream.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
work="$TMPDIR/d6codec-kinit-v1365"
source="$work/stage1-generated-v1365/stage1-mtc-v1364.s"
stream="$work/kinit-grouped-v1365.words"
test -s "$source" && test -s "$stream"
dxr="$work/stage1-mtc-v1365.dxr"
paper="$work/stage1-mtc-v1365.pt"
tape="$work/kinit-grouped-mtc-v1365.tap"
das -F -K -O "$dxr" "$source"
dxrconvert --pdp6-readin -b 060 "$dxr" "$paper"
mktap -t mtc -p "$stream" -o "$tape"
descriptor=$(sed -n '2p' "$stream")
entry_offset=$(printf '%s\n' "$descriptor" | cut -c 7-12)
entry=$(printf '%06o' "$((030000 + 0$entry_offset))")
first=$(sed -n '3p' "$DAIMOS_REPO/build/system/boot/pdp6/kinit.words")
ini="$work/boot-mtc-grouped-v1365.simh"
out="$work/boot-mtc-grouped-v1365.out"
cat > "$ini" <<EOF_SIMH
set cpu 256k
set ptr enabled
set dct enabled
set mtc dct=0
set mtc enabled
set mtc0 enabled
set mtc0 7t
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
attach -q mtc0 $tape
break $entry
go 020
ex pc
ex 030000
exit
EOF_SIMH
if ! timeout -k 2s 90s "$PDP10_PREFIX/bin/pdp6" "$ini" \
    </dev/null > "$out" 2>&1; then
    tail -70 "$out" >&2
    echo 'v1365: magnetic-tape Stage-1 did not reach KINIT entry' >&2
    exit 1
fi
if ! grep -F "Breakpoint, PC: $entry" "$out" >/dev/null || \
   ! grep -F "$first" "$out" >/dev/null; then
    tail -70 "$out" >&2
    echo 'v1365: magnetic-tape grouped decode/KINIT entry mismatch' >&2
    exit 1
fi
echo "PASS v1365: actual Stage0/Type-516 MTC -> grouped Stage1 -> KINIT entry $entry"
