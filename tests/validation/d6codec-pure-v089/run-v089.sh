#!/bin/sh
# Verify genuine host DLINK --pure flag and no-text-write admission.
set -eu
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
dlink=${DLINK:-$PDP10_PREFIX/bin/dlink}
work="$TMPDIR/d6codec-pure-v089-test"
mkdir -p "$work"
cat > "$work/pure.s" <<'ASM'
.text
.globl __start
.entry __start
__start:
 setz 1,
 popj 17,
ASM
cat > "$work/writes-text.s" <<'ASM'
.text
.globl __start
.entry __start
__start:
 setz 1,
 movem 1,__start
 popj 17,
ASM
for name in pure writes-text; do
 "$PDP10_PREFIX/bin/das" -F -C -O "$work/$name.dobj" "$work/$name.s"
done
"$dlink" -b 020 --pure -o "$work/pure.dxr" "$work/pure.dobj"
python3 - "$work/pure.dxr" <<'PY'
from pathlib import Path
import sys
raw=Path(sys.argv[1]).read_bytes()
assert len(raw) >= 24 and len(raw)%8 == 0
header=[int.from_bytes(raw[i:i+8], 'little') for i in range(0,24,8)]
assert header[1] & 0o200000 and not header[1] & 0o100000
assert header[2]&0o777777 == 0o647022
print('PASS v089 host DLINK --pure header')
PY
if "$dlink" -b 020 --pure -o "$work/writes-text.dxr" "$work/writes-text.dobj"; then
 echo 'FAIL v089: --pure accepted definite self-modifying TEXT store' >&2
 exit 1
fi
echo 'PASS v089 host DLINK rejects definite TEXT write'
