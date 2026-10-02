#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_TOOLS_REPO:?PDP10_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

cc=${HOST_CC:-cc}
tag=host-d6lz-exec-v1
work="$TMPDIR/$tag-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

make -s -C "$DAIMOS_REPO/userland" build \
        BUILD_ROOT="$work/build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
src=`find "$work/build" -name tsfsprobe.dxr -type f | head -1`
[ -n "$src" ] && [ -f "$src" ] || {
        echo "$tag: TSFSPROBE build output missing" >&2
        exit 1
}
"$cc" -std=c99 -O2 -Wall -Wextra -Werror \
        -o "$work/d6lz" "$PDP10_TOOLS_REPO/d6lz.c"
"$work/d6lz" -x "$src" "$work/compressed.dxr"
python3 - "$src" "$work/compressed.dxr" <<'PY'
import struct, sys
MASK = (1 << 36) - 1
HALF = (1 << 18) - 1
F_COMPRESSED = 0o100000

def load(path):
    data = open(path, 'rb').read()
    if len(data) % 8:
        raise SystemExit('word container has partial word')
    return [struct.unpack_from('<Q', data, i)[0]
            for i in range(0, len(data), 8)]

plain = load(sys.argv[1])
comp = load(sys.argv[2])
if len(plain) < 2 or len(comp) < 3:
    raise SystemExit('short DXR')
if (comp[1] & F_COMPRESSED) == 0:
    raise SystemExit('compressed flag missing')
image = (plain[1] >> 18) & HALF
reloc = (image + 35) // 36
header = 3 if len(plain) == 3 + image + reloc else 2
if len(plain) != header + image + reloc:
    raise SystemExit('plain DXR shape invalid')
payload = comp[3:len(comp) - reloc]
out = []
ip = 0
while len(out) < image:
    if ip >= len(payload):
        raise SystemExit('truncated control stream')
    control = payload[ip]
    ip += 1
    mask = 1 << 35
    for _ in range(36):
        if len(out) >= image:
            break
        if ip >= len(payload):
            raise SystemExit('truncated token stream')
        token = payload[ip]
        ip += 1
        if control & mask:
            if token >> 14:
                raise SystemExit('reserved descriptor bits set')
            dist = (token & 0x7f) + 1
            length = ((token >> 7) & 0x7f) + 3
            if dist > len(out) or len(out) + length > image:
                raise SystemExit('invalid back-reference')
            for _ in range(length):
                out.append(out[-dist])
        else:
            out.append(token & MASK)
        mask >>= 1
if ip != len(payload):
    raise SystemExit('unused compressed payload')
if out != plain[header:header + image]:
    raise SystemExit('decoded image differs')
if comp[-reloc:] != plain[-reloc:]:
    raise SystemExit('relocation map differs')
print('host-d6lz-exec-v1: PASS')
PY
