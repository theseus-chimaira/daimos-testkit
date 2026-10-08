#!/bin/sh
# Regression: the KCC peephole must not mutate an instruction before
# rejecting a TRNA/JRST/MOVE fold guarded by a SKIP chain.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}"
w="$TMPDIR/daimos-kcc-foldtrna-conditional-20261008-v1-$$"
trap 'rm -rf "$w"' EXIT HUP INT TERM
mkdir -p "$w"
k="$DAIMOS_REPO/system/kernel"
(cd "$k" && "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
 -DKINIT_FULL=1 -DKINIT_BADMAP=1 -DKINIT_STACK_RESERVE_WORDS=02000 \
 -DKINIT_STACK_WATERMARK=0 -DPROC_BOOT_USERS=1 -DPROC_STACK_WATERMARK=0 \
 -I. -Iboot -Icore -Idrivers -Ifs -Iipc -Imm -Imodules -Iproc -Istorage \
 -I"$PDP10_PREFIX/include" -S modules/module_minit.c -o "$w/out.s") >/dev/null
python3 - "$w/out.s" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
m=re.search(r'^logstore_minit:\n(.*?)(?=^\s*\.bss|^\s*\.globl|\Z)',s,re.S|re.M)
assert m, 'no LOGSTORE initialization'
a=m.group(1)
pat=r'skipn\s+\d+,auxstore_logstore_blocks\s*\n\s*skipe\s+\d+,[^\n]+\s*\n\s*trna\s*\n\s*jrst\s+[^\n]+\s*\n\s*move\s+\d+,\[POINT 6,'
assert re.search(pat,a,re.I), 'unsafe FOLDTRNA peephole / missing ordinary MOVE'
print('kcc-foldtrna-conditional-v1: PASS')
PY
