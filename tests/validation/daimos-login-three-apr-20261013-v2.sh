#!/bin/sh
# Fresh-build LOGIN v2 resident-size/stack-format regression.
set -eu
: "${LOGIN_DXR:?set LOGIN_DXR}"
: "${DXRCHECK:=dxrcheck}"
record=$("$DXRCHECK" "$LOGIN_DXR")
python3 - "$LOGIN_DXR" "$record" <<'PYTEST'
import re
from pathlib import Path
import sys

m = re.search(r'DXR image=([0-7]+) bss=([0-7]+)', sys.argv[2])
if m is None:
    raise SystemExit('FAIL: no DXR image/BSS fields')
image, bss = (int(x, 8) for x in m.groups())
data = Path(sys.argv[1]).read_bytes()
if len(data) < 24:
    raise SystemExit('FAIL: truncated DXR')
st2 = int.from_bytes(data[16:24], 'little')
if (st2 & 0o777777) != 0o636422 or (st2 >> 18) != 0o1000:
    raise SystemExit('FAIL: lost ST2 01000 stack reserve')
required = image + bss + 0o20 + 0o1000
rounded = (required + 0o1777) & ~0o1777
if rounded != 0o6000:
    raise SystemExit('FAIL: resident extent %o, expected 6000' % rounded)
print('PASS: image=%o bss=%o stack=1000 required=%o APR=%o' %
      (image, bss, required, rounded))
PYTEST
