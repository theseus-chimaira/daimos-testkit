#!/bin/sh
# Test-only real Stage0 -> grouped Stage1 -> KINIT entry on PDP-6/DECtape.
# Does not mutate the production boot Makefile or generated media.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-kinit-v1365"
boot="$DAIMOS_REPO/build/system/boot/pdp6"
mkdir -p "$work"

# Rebuild the real linked KINIT if any prerequisites changed. Only
# ignored build outputs are written, never production boot media.
if ! make -C "$DAIMOS_REPO/system/boot/pdp6" \
    "$boot/kinit.words" > "$work/build-real-kinit-v1365.log" 2>&1; then
    tail -70 "$work/build-real-kinit-v1365.log" >&2
    exit 1
fi
test -s "$boot/kinit.words"
stream="$work/kinit-grouped-v1365.words"
rm -f "$stream"
python3 -B "$testkit/tests/validation/d6codec-kinit-image-v1365/make_grouped_kinit_v1365.py" \
    "$boot/kinit.words" "$stream" 01000000 0400

# Generate the native v1364 guarded, complete-buffer Stage1 with no
# low-core decoder copy. Only the test-specific output tree is touched.
out="$work/stage1-generated-v1365"
python3 -B "$testkit/tests/validation/d6codec-stage1-geometry-v1364/generate-v1364.py" \
    "$DAIMOS_REPO" "$testkit" "$out" 01000000 0400 > "$work/stage1-generated-v1365.log"
source="$out/stage1-dtc-v1364.s"
dxr="$work/stage1-dtc-v1365.dxr"
paper="$work/stage1-dtc-v1365.pt"
dec="$work/kinit-grouped-dtc-v1365.dta"
das -F -K -L "$work/stage1-dtc-v1365.labels" -O "$dxr" "$source"
dxrconvert --pdp6-readin -b 060 "$dxr" "$paper"
mkdt -t dtc -p "$stream" -o "$dec"
test -s "$paper" && test -s "$dec"

descriptor=$(sed -n '2p' "$stream")
entry_offset=$(printf '%s\n' "$descriptor" | cut -c 7-12)
entry=$(printf '%06o' "$((030000 + 0$entry_offset))")
first=$(sed -n '3p' "$boot/kinit.words")
ini="$work/boot-dtc-grouped-v1365.simh"
simh_out="$work/boot-dtc-grouped-v1365.out"
cat > "$ini" <<EOF_SIMH
set cpu 256k
set ptr enabled
set dct enabled
set dtc dct=04
set dtc enabled
set dtc0 enabled
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
attach -q dtc0 $dec
break $entry
go 020
ex pc
ex 030000
exit
EOF_SIMH

# This exercises actual Type-760 Stage0 loading and Type-136 DTC reads.
# Only reaching KINIT entry is asserted: the running kernel still embeds
# legacy D6LZ36 runtime consumers, not production grouped consumers.
if ! timeout -k 2s 90s "$PDP10_PREFIX/bin/pdp6" "$ini" \
    </dev/null > "$simh_out" 2>&1; then
    tail -70 "$simh_out" >&2
    echo 'v1365: grouped DECtape boot did not reach KINIT entry' >&2
    exit 1
fi
if ! grep -F "Breakpoint, PC: $entry" "$simh_out" >/dev/null; then
    tail -70 "$simh_out" >&2
    echo "v1365: missing expected KINIT entry breakpoint $entry" >&2
    exit 1
fi
if ! grep -F "$first" "$simh_out" >/dev/null; then
    tail -70 "$simh_out" >&2
    echo 'v1365: decoded KINIT first word not observed in simulated RAM' >&2
    exit 1
fi
echo "PASS v1365: actual Stage0/Type-136 DTC -> grouped Stage1 -> KINIT entry $entry"
