#!/bin/sh
# Execute the actual RUN credential-publication instructions in isolation.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-run-identity-v1924.XXXXXX")
trap 'echo "v1924 RUN evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_run.s" "$work" <<'PY'
from pathlib import Path
import sys
src, work=map(Path,sys.argv[1:])
s=src.read_text()
a='        move    4,040(7)\n'; b='proc_run_pure_ext_ready:'
assert s.count(a)==1 and s.count(b)==1
leaf='.text\n.globl publish_v1924\n.equ PROC_CRED_OFFSET,066\npublish_v1924:\n'+s[s.index(a):s.index(b)]+'        popj 17,\n'
(work/'publish.s').write_text(leaf)
a='        dpb     4,[POINT 4,PROC_CRED_OFFSET(014),7]\n'; assert leaf.count(a)==1
(work/'unsafe.s').write_text(leaf.replace(a,''))
(work/'unsafe-marker-v1976.s').write_text(leaf.replace('POINT 4,', 'POINT 3,'))
lines=['.data\n.globl cases_v1924\ncases_v1924:\n']
for provider in range(4,8):
    for high in (0,1):
        for rollback in (0,2):
            for parent_mark in (0,1):
                for child_mark in (0,1):
                    parent=0o017234567123|(parent_mark<<31)
                    stage=(provider<<2)|high|rollback|(child_mark<<5)
                    expected=(parent & ~0o037000000000)|(provider<<28)|(high<<27)|(child_mark<<31)
                    for value in (parent,stage,expected):
                        lines.append(' .word 0%012o\n'%value)
(work/'cases.s').write_text(''.join(lines))
PY
for variant in publish unsafe unsafe-marker-v1976; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "run-identity-$variant-v1924" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-run-v1924.s" "$work/cases.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
        [ "$variant" = publish ] || { echo 'FAIL: missing provider copy accepted'; exit 1; }
        cat "$work/$variant.log"
    else
        [ "$variant" != publish ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
        echo "PASS: $variant RUN transfer rejected"
    fi
done
