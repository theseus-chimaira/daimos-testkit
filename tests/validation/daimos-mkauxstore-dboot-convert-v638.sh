#!/bin/sh
# Conversion of a verified DBOOT header into AUXST1 on a disposable image.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-dboot-v638.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
tool="$DAIMOS_REPO/build/tools/host/mkauxstore"
image="$work/aux.dsk"
"$tool" --blank "$image" --blocks 0200
python3 - "$image" <<'PY'
import struct
import sys
words = [0] * 128
words[0] = 0o444243000000
words[5] = 0o4010000
words[6] = 0o442654636222
words[7] = (1 << 18) | 0o20
words[8] = 0
words[9] = 1
words[10] = 0o157
with open(sys.argv[1], 'r+b') as f:
    f.write(struct.pack('<128Q', *words))
    f.seek(10 * 1024)
    f.write(b'X')
PY
args='--d6fs-base 1 --d6fs-blocks 020 --d6fs-super-a 0 --d6fs-super-b 1 --backstore-blocks 010 --logstore-blocks 0 --cache-blocks 0147'
cp "$image" "$work/before"
if "$tool" -i "$image" --confirm-destructive $args >/dev/null 2>&1; then
    echo 'v638: nonempty DBOOT accepted without conversion flag' >&2; exit 1
fi
cmp "$image" "$work/before"
"$tool" -i "$image" --dry-run --convert-dboot $args >/dev/null
cmp "$image" "$work/before"
"$tool" -i "$image" --confirm-destructive --convert-dboot $args >/dev/null
"$tool" --inspect "$image" > "$work/inspect"
grep -q 'BACKSTORE 21+10' "$work/inspect"
test "$(dd if="$image" bs=1 skip=$((10 * 1024)) count=1 2>/dev/null)" = X
"$tool" --blank "$work/mismatch" --blocks 0200
python3 - "$work/mismatch" <<'PY'
import struct
import sys
with open(sys.argv[1], 'r+b') as f:
    w = [0] * 128
    w[0] = 0o444243000000
    w[5] = 0o4010000
    w[6] = 0o442654636222
    w[7] = (1 << 18) | 0o21
    w[9] = 1
    w[10] = 0o157
    f.write(struct.pack('<128Q', *w))
PY
cp "$work/mismatch" "$work/mismatch.before"
if "$tool" -i "$work/mismatch" --confirm-destructive --convert-dboot $args >/dev/null 2>&1; then
    echo 'v638: mismatched DBOOT layout accepted' >&2; exit 1
fi
cmp "$work/mismatch" "$work/mismatch.before"
# The DBOOT converter must not discard non-36-bit high bits in an image.
cp "$work/before" "$work/highbits"
printf '\200' | dd of="$work/highbits" bs=1 seek=7 conv=notrunc 2>/dev/null
cp "$work/highbits" "$work/highbits.before"
if "$tool" -i "$work/highbits" --confirm-destructive --convert-dboot $args >/dev/null 2>&1; then
    echo 'v638: high-bit DBOOT corruption accepted' >&2; exit 1
fi
cmp "$work/highbits" "$work/highbits.before"
echo 'daimos-mkauxstore-dboot-convert-v638: PASS'
