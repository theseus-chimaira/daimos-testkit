#!/bin/sh
# Two actual PDP-6 Type-760 PTR media streams, after isolated DTC prep.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
work="$TMPDIR/d6codec-kinit-v1365"
source="$work/stage1-generated-v1365/stage1-ptr-v1364.s"
stream="$work/kinit-grouped-v1365.words"
test -s "$source" && test -s "$stream"
dxr="$work/stage1-ptr-v1365.dxr"
paper="$work/stage1-ptr-v1365.pt"
das -F -K -O "$dxr" "$source"
dxrconvert --pdp6-readin -b 060 "$dxr" "$paper"
payload=$(( $(wc -l < "$stream") - 3 ))
first=$(( (payload + 1) / 2 ))
second=$(( payload - first ))
test "$first" -gt 0 && test "$second" -gt 0
firstwords="$work/kinit-grouped-ptr1-v1365.words"
secondwords="$work/kinit-grouped-ptr2-v1365.words"
firsttape="$work/kinit-grouped-ptr1-v1365.pt"
secondtape="$work/kinit-grouped-ptr2-v1365.pt"
{
  printf '%012o\n' $((first + 3))
  head -n 3 "$stream"
  tail -n +4 "$stream" | head -n "$first"
} > "$firstwords"
{
  printf '%012o\n' "$second"
  tail -n +4 "$stream" | tail -n "$second"
} > "$secondwords"
test "$(wc -l < "$firstwords")" -eq $((first + 4))
test "$(wc -l < "$secondwords")" -eq $((second + 1))
words2pt -t ptr -p "$firstwords" -o "$firsttape"
words2pt -t ptr -p "$secondwords" -o "$secondtape"
descriptor=$(sed -n '2p' "$stream")
entry_offset=$(printf '%s\n' "$descriptor" | cut -c 7-12)
entry=$(printf '%06o' "$((030000 + 0$entry_offset))")
firstword=$(sed -n '3p' "$DAIMOS_REPO/build/system/boot/pdp6/kinit.words")
ini="$work/boot-ptr-grouped-v1365.simh"
out="$work/boot-ptr-grouped-v1365.out"
cat > "$ini" <<EOF_SIMH
set cpu 256k
set ptr enabled
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
break 060
go 020
nobreak 060
detach ptr
attach -q ptr $firsttape
deposit ptr time 1
expect "TAPE2" detach ptr; attach -q ptr $secondtape; deposit ptr time 1; continue
break $entry
go 060
ex pc
ex 030000
exit
EOF_SIMH
if ! timeout -k 2s 120s "$PDP10_PREFIX/bin/pdp6" "$ini" \
    </dev/null > "$out" 2>&1; then
    tail -75 "$out" >&2
    echo 'v1365: two-tape PTR Stage-1 did not reach KINIT entry' >&2
    exit 1
fi
if ! grep -F "Breakpoint, PC: $entry" "$out" >/dev/null || \
   ! grep -F "$firstword" "$out" >/dev/null; then
    tail -75 "$out" >&2
    echo 'v1365: two-tape grouped PTR decode/KINIT entry mismatch' >&2
    exit 1
fi
echo "PASS v1365: actual Stage0/two-volume PTR -> grouped Stage1 -> KINIT entry $entry"
