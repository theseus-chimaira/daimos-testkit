#!/bin/sh
# Prepare BOTH authentic alternative DAIMOS Stage-1 boot paths for AAP.
# The optional test below proves Stage-1 execution only, NOT kernel boot.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
out=${AAP_ALT_BOOT_OUT:-$TMPDIR/aap-alt-stage1-media-v1}
image=${DAIMOS_COMPRESSED_WORDS:-$root/DAIMOS/build/system/boot/pdp6/kinit.d6lz.words}
das_bin=${DAS:-$root/das/das}
converter=${DXRCONVERT:-$root/das/dxrconvert}
words2pt=${WORDS2PT:-$root/daimos-tools/words2pt}
mkdt=${MKDT:-$root/daimos-tools/mkdt}
for executable in "$das_bin" "$converter" "$words2pt" "$mkdt"; do
  test -x "$executable" || { echo "Missing tool: $executable" >&2; exit 1; }
done
test -s "$image" || { echo "Missing compressed KINIT image: $image" >&2; exit 1; }
mkdir -p "$out"
for mode in ptr dtc; do
  "$das_bin" -F -K -O "$out/stage1-$mode-v1.dxr" "$root/DAIMOS/system/stand/pdp6/$mode/stage1.s"
  "$converter" --pdp6-readin -b 060 "$out/stage1-$mode-v1.dxr" "$out/stage1-$mode-v1.pt"
  if [ "$mode" = ptr ]; then
    # RIM terminal byte 0252 is not part of the executable image. On AAP
    # it becomes a stale first byte of the following counted payload.
    cp "$out/stage1-ptr-v1.pt" "$out/stage1-ptr-no-trailer-v2.pt"
  fi
  printf '\252' >> "$out/stage1-$mode-v1.pt"
done
cwords=$(($(wc -l < "$image") - 3))
first=$(((cwords+1)/2))
second=$((cwords-first))
test "$first" -gt 0 && test "$second" -gt 0
{ printf '%012o\n' $((first+3)); head -n 3 "$image"; tail -n +4 "$image" | head -n "$first"; } > "$out/ptr-boot1-v1.words"
{ printf '%012o\n' "$second"; tail -n +4 "$image" | tail -n "$second"; } > "$out/ptr-boot2-v1.words"
"$words2pt" -t ptr -p "$out/ptr-boot1-v1.words" -o "$out/ptr-boot1-v1.pt"
"$words2pt" -t ptr -p "$out/ptr-boot2-v1.words" -o "$out/ptr-boot2-v1.pt"
"$mkdt" -t dtc -p "$image" -o "$out/dtc0-simh-v1.tap"
for f in stage1-ptr-v1.pt stage1-ptr-no-trailer-v2.pt stage1-dtc-v1.pt ptr-boot1-v1.pt ptr-boot2-v1.pt dtc0-simh-v1.tap; do test -s "$out/$f"; done
printf 'AAP dual Stage-1 media prepared: %s\n' "$out"
printf 'Paper tape: Stage-1 + payload tapes 1 and 2 (operator must swap)\n'
printf 'DECtape: Stage-1 PTR read-in + SIMH-format halfword image only; AAP raw Type-555 image is NOT generated\n'
printf 'No KINIT/KCORE/MRES runtime execution has been claimed.\n'
# AAP Type-555 expects a raw per-line mark/data stream, NOT the SIMH
# 32-bit-container, 18-bit-halfword stream. Never name the latter as if
# it were directly mountable AAP media.
python3 - "$out/dtc0-simh-v1.tap" <<'PY_CHECK'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); data=p.read_bytes()
assert data and len(data)%4 == 0, 'expected SIMH 32-bit halfword containers'
# Both halfwords are serialized as 32-bit little-endian containers.
for offset in range(0, len(data), 4):
    assert int.from_bytes(data[offset:offset+4], 'little') < (1 << 18), ('invalid 18-bit halfword',offset)
print('DECtape format: SIMH 32-bit halfwords; AAP Type-555 raw-line conversion required')
PY_CHECK

python3 - "$out/stage1-ptr-v1.pt" "$out/stage1-ptr-no-trailer-v2.pt" <<'PY_VERIFY'
from pathlib import Path
import sys
original,corrected=map(lambda v:Path(v).read_bytes(),sys.argv[1:])
assert original==corrected+bytes([0o252])
print('PTR read-in variants: reference trailer 0252, corrected version excludes it')
PY_VERIFY
