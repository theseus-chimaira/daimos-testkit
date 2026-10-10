#!/bin/sh
# The intrusive run queue must reject double enqueue before changing links.
set -eu
: "${DAIMOS_REPO:?}" "${TMPDIR:?}"
src=$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s
awk '
/proc_runq_add:/ {on=1}
/proc_runq_remove:/ {on=0}
on {print}
' "$src" > "$TMPDIR/daimos-runq-idempotence-20261010-v1-$$.txt"
f="$TMPDIR/daimos-runq-idempotence-20261010-v1-$$.txt"
trap 'rm -f "$f"' EXIT HUP INT TERM
grep -q 'proc_runq_add_check:' "$f"
grep -q 'camn    6,1' "$f"
grep -q 'proc_runq_add_new:' "$f"
python3 - "$f" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a=s.index('proc_runq_add_check:')
b=s.index('proc_runq_add_new:')
c=s.index('hrrm    0,2(5)')
assert a < b < c
assert 'camn    6,1\n        popj    17,' in s[a:b]
assert 'hrrz    6,2(7)' in s[a:b]
print('PASS: duplicate membership rejected before runq link mutation')
PY
w="$TMPDIR/daimos-runq-idempotence-20261010-v1-$$.s"
o="$TMPDIR/daimos-runq-idempotence-20261010-v1-$$.dobj"
trap 'rm -f "$f" "$w" "$o"' EXIT HUP INT TERM
{ echo '.set PROC_STACK_WATERMARK,0'; echo '.set KINIT_STACK_WATERMARK,0'; cat "$src"; } > "$w"
"${PDP10_DAS:-/usr/local/bin/das}" -F -C -O "$o" "$w"
echo 'PASS: modified scheduler assembles'
