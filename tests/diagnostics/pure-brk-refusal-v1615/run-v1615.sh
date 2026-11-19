#!/bin/sh
# Non-accepting 48K physical BRK refusal classification, v1615.
# Use the unchanged v1614 test source and guest harness as a base,
# changing only BRK demand, preserving the exact typed AC2 cause and
# stopping the guest BEFORE terminal cleanup to snapshot exact MM owners.
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
source="$here/../pure-brk-pressure-v1614/test-v1614.c"
work=$(mktemp -d "$TMPDIR/pure-brk-refusal-v1615.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$source" "$work/test-v1615.c" <<'PY'
from pathlib import Path
import os,re,sys
s=Path(sys.argv[1]).read_text()
old='#define P14_BRK_TARGET       022000UL'
assert s.count(old)==1
target=os.environ.get('PURE_BRK_TARGET_V1615','014000')
assert re.fullmatch(r'0[0-7]+',target)
s=s.replace(old,'#define P14_BRK_TARGET       '+target+'UL',1)
old='#include "proc.h"'
assert s.count(old)==1
s=s.replace(old,old+'\n\nextern kword_t dsys_brk_cause_v1615(kword_t);\nkword_t brk_cause_v1615;',1)
old='''    if (target <= old_brk || dsys_brk(target) != target)
        p14_fail('G');'''
new='''    if (target <= old_brk ||
        dsys_brk_cause_v1615(target) != target) {
        (void)p14_char('C');
        p14_octal(brk_cause_v1615);
        (void)p14_char('F');
        (void)dsys_halt();
        p14_fail('G');
    }'''
assert s.count(old)==1
s=s.replace(old,new,1)
if os.environ.get('PURE_BRK_STEPS_V1615','0') == '1':
    old='''    target = P14_BRK_TARGET;'''
    new='''    /* Establish the two smaller APR growth steps first. They must not
     * be confused with a successful RAW drop; live MM is inspected
     * after the final pressure step and before any owner is reaped. */
    for (i = 0U; i < 2U; ++i) {
        kword_t step = i ? 016000UL : 014000UL;
        (void)p14_char(i ? '2' : '1');
        if (dsys_brk_cause_v1615(step) != step) {
            (void)p14_char('C');
            p14_octal(brk_cause_v1615);
            (void)p14_char('F');
            (void)dsys_halt();
            p14_fail('g');
        }
        p14_stat(i ? '2' : '1');
    }
    target = P14_BRK_TARGET;'''
    assert s.count(old)==1
    s=s.replace(old,new,1)
old='''    p14_stat('A');

    /* Logical mapped words exclude a PACKED owner.'''
new='''    p14_stat('A');
    /* Stop before closing the PIPE or reaping any children. The SIMH
     * monitor may now examine the MM table with all owners still live. */
    (void)p14_char('H');
    (void)dsys_halt();
    p14_fail('h');

    /* Logical mapped words exclude a PACKED owner.'''
assert s.count(old)==1
s=s.replace(old,new,1)
Path(sys.argv[2]).write_text(s)
PY
PURE_BRK_SOURCE_V1615="$work/test-v1615.c"
PURE_BRK_VENEER_V1615="$here/brk-cause-v1615.s"
PURE_MM_DUMP_V1615=1
PURE_DIAG_HALT_V1615=1
KEEP_TEST=1
export PURE_BRK_SOURCE_V1615 PURE_BRK_VENEER_V1615 \
    PURE_MM_DUMP_V1615 PURE_DIAG_HALT_V1615 KEEP_TEST
echo "v1615: physical BRK target ${PURE_BRK_TARGET_V1615:-014000}, steps=${PURE_BRK_STEPS_V1615:-0}; typed AC2 and pre-cleanup MM snapshot"
exec sh "$here/../pure-brk-pressure-v1614/run-v1614.sh"
