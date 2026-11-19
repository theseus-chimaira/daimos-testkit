#!/bin/sh
# Add a compressed DXR2 PURE copy of the source-identical INIT to
# TSFS and regenerate actual three-member boot tapes. No kernel patch.
set -eu
test "$#" -eq 2
work=$1
boot=$2
: "${PDP10_PREFIX:?installed PDP-6 host toolchain required}"
image="$work/user/init.dxr"
compressed="$work/user/comp-v1638.dxr"
manifest="$work/tsfs-root-v1638.manifest"
test -s "$image"
test -s "$boot/tsfs-root.manifest"
test -s "$boot/kinit.lowmem.words"
test -x "$boot/d6block-v1464"
test -x "$boot/mktsfs-v1461"
"$boot/d6block-v1464" -x "$image" "$compressed"
# The installed dxrcheck inspects PLAIN DXR images only: its legacy
# payload length test falsely calls compressed input truncated. Inspect
# actual DXR2 headers and the exact compressed file word length instead;
# mktsfs/tsfscheck independently validates this source on its real media.
python3 - "$image" "$compressed" <<'PY'
from pathlib import Path
import sys


def words(path):
    raw = Path(path).read_bytes()
    assert len(raw) % 8 == 0 and len(raw) >= 24
    return [int.from_bytes(raw[i:i+8], "little")
            for i in range(0, len(raw), 8)]


plain, comp = (words(path) for path in sys.argv[1:])
assert plain[:3][0] == comp[:3][0]
assert (comp[1] >> 18) == (plain[1] >> 18)
assert (plain[1] & 0o300000) == 0o200000
assert (comp[1] & 0o300000) == 0o300000
assert comp[2] == plain[2]
image_words = plain[1] >> 18
reloc = (image_words + 35) // 36
payload = len(comp) - 3 - reloc
assert payload > 0 and len(plain) == 3 + image_words + reloc
print("v1638: verified PURE+COMPRESSED DXR2 image=%06o "
      "packed=%06o reloc=%06o" % (image_words, payload, reloc))
PY
cp "$boot/tsfs-root.manifest" "$manifest"
printf 'F /SYSTEM/COMP %s 0555 0 0\n' "$compressed" >>"$manifest"
root="$work/tsfs-v1638"
"$boot/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$manifest" \
    -b "$boot/kinit.lowmem.words" -o "$root"
"$boot/tsfscheck-v1461" "$root"0.dta "$root"1.dta "$root"2.dta
for unit in 0 1 2; do
    cp "$root$unit.dta" "$boot/media/dtc$unit.tap"
done
echo 'v1638: original TSFS boot rebuilt with compressed PURE /SYSTEM/COMP'
