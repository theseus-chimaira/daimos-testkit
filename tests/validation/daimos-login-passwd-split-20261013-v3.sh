#!/bin/sh
# Validate the in-process account reader split and LOGIN resident extent.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${LOGIN_DXR:?set LOGIN_DXR}"
: "${DXRCHECK:=dxrcheck}"
test -f "$DAIMOS_REPO/userland/login/passwd_reader.c"
test -f "$DAIMOS_REPO/userland/login/passwd_reader.h"
grep -q 'login_find_account' "$DAIMOS_REPO/userland/login/passwd_reader.c"
grep -q 'login_find_account' "$DAIMOS_REPO/userland/login/login.c"
grep -q 'ulog_event' "$DAIMOS_REPO/userland/login/login.c"
record=$("$DXRCHECK" "$LOGIN_DXR")
python3 - "$LOGIN_DXR" "$record" <<'PYTEST'
import re
from pathlib import Path
import sys
m = re.search(r'DXR image=([0-7]+) bss=([0-7]+)', sys.argv[2])
if m is None:
    raise SystemExit('FAIL: missing DXR metadata')
image, bss = (int(n, 8) for n in m.groups())
raw = Path(sys.argv[1]).read_bytes()
if len(raw) < 24:
    raise SystemExit('FAIL: truncated DXR header')
st2 = int.from_bytes(raw[16:24], 'little')
stack = st2 >> 18
if st2 & 0o777777 != 0o636422 or stack != 0o1000:
    raise SystemExit('FAIL: lost ST2 stack')
required = image + bss + 0o20 + stack
rounded = (required + 0o1777) & ~0o1777
if rounded != 0o6000:
    raise SystemExit('FAIL: LOGIN extent %o instead of 6000' % rounded)
print('PASS LOGIN reader split image=%o bss=%o required=%o APR=%o' %
      (image, bss, required, rounded))
PYTEST
