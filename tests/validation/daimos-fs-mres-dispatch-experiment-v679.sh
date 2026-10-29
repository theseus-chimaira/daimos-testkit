#!/bin/sh
# Non-production assembler experiment: eliminate redundant target extraction.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-fs-dispatch-v679.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])
fast_old = '        hrrz    7,fs_memfs_service_jump(7)\n        jrst    (7)'
fast_new = '        jrst    @fs_memfs_service_jump(7)'
locked_old = ('        hrrz    7,fs_memfs_service_jump(7)\n'
              '        ; The missing-service trampoline already returns -1 normally.\n'
              '        ; Invoke it under the same lease and use the common unlock path.\n'
              '        pushj   17,(7)')
locked_new = ('        ; Preserve the existing lease; indirect call uses the\n'
              '        ; KINIT-patched JRST word as its effective address.\n'
              '        pushj   17,@fs_memfs_service_jump(7)')
assert src.count(fast_old) == 1
assert src.count(locked_old) == 1
optimized = src.replace(fast_old, fast_new).replace(locked_old, locked_new)
(out / 'baseline.s').write_text(src)
(out / 'indirect.s').write_text(optimized)
print('Shared-lock indirect experiment: 2 candidate words saved')
print('Direct per-operation alternative: at least one binding/site plus retargeting; not implemented')
PY
das -F -C -O "$work/baseline.dobj" "$work/baseline.s"
das -F -C -O "$work/indirect.dobj" "$work/indirect.s"
printf '%s\n' 'v679: both variants assembled; production unchanged'
