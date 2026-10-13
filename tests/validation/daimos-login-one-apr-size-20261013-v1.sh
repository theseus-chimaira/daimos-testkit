#!/bin/sh
# Verify the actual LOGIN DXR2 ST2 stack field and PDP-6 APR allocation.
set -eu
: "${LOGIN_DXR:?set LOGIN_DXR to the uncompressed LOGIN executable}"
: "${DXRCHECK:=dxrcheck}"
record=$("$DXRCHECK" "$LOGIN_DXR")
image=$(printf '%s\n' "$record" | sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p')
bss=$(printf '%s\n' "$record" | sed -n 's/^DXR image=[0-7][0-7]* bss=\([0-7][0-7]*\).*/\1/p')
test -n "$image" && test -n "$bss" || {
    echo 'FAIL: cannot read LOGIN image and BSS' >&2
    exit 1
}
python3 - "$LOGIN_DXR" "$image" "$bss" <<'PYTEST'
from pathlib import Path
import sys

raw = Path(sys.argv[1]).read_bytes()
if len(raw) < 24:
    raise SystemExit('FAIL: truncated LOGIN DXR2 header')
metadata = int.from_bytes(raw[16:24], 'little')
stack = metadata >> 18
if metadata & 0o777777 != 0o636422 or stack != 0o1000:
    raise SystemExit('FAIL: LOGIN ST2 stack is not 01000')
image = int(sys.argv[2], 8)
bss = int(sys.argv[3], 8)
required = image + bss + 0o20 + stack
rounded = (required + 0o1777) & ~0o1777
if rounded != 0o10000:
    raise SystemExit('FAIL: LOGIN APR allocation is %o, expected 10000' % rounded)
print('PASS LOGIN image=%o BSS=%o stack=%o required=%o APR=%o' %
      (image, bss, stack, required, rounded))
PYTEST
