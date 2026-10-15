#!/bin/sh
# Verify genuine host DLINK --pure flag and no-text-write admission.
set -eu
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
dlink=${DLINK:-$PDP10_PREFIX/bin/dlink}
work="$TMPDIR/d6codec-pure-v090-test"
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
print('PASS v090 host DLINK --pure header')
PY
if "$dlink" -b 020 --pure -o "$work/writes-text.dxr" "$work/writes-text.dobj"; then
 echo 'FAIL v090: --pure accepted definite self-modifying TEXT store' >&2
 exit 1
fi
echo 'PASS v090 host DLINK rejects definite TEXT write'
: "${DAIMOS_REPO:?}"
cc -std=c99 -O2 -Wall -Wextra -Werror \
 "$DAIMOS_REPO/tools/host/d6lz.c" "$DAIMOS_REPO/tools/host/d6codec-group-v072.c" \
 -o "$work/group-encode"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" \
 "$(dirname "$0")/check-v090.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" -o "$work/check"
"$work/group-encode" -x "$work/pure.dxr" "$work/pure.group.dxr"
"$work/check" "$work/pure.dxr" "$work/pure.group.dxr"
# A native PDP-6 decoder must independently accept the linked PURE payload.
python3 "$(dirname "$0")/make-native-v090.py" \
 "$work/pure.dxr" "$work/pure.group.dxr" "$work/pure-native.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode go --start 1000 --timeout 20 \
 --workdir "$work/native-runtime" --name d6codec-pure-native-v090 \
 --expect __test_exit=0 \
 "$(dirname "$0")/../../validation/daimos-test-crt0-v1.s" \
 "$work/pure-native.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"
