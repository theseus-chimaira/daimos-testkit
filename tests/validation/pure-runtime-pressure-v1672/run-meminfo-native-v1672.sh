#!/bin/sh
# Test actual assembler leaf instructions, including ZOMB after EXIT and
# swapped VM with zero physical base. Mutants must fail under p10run.
set -eu
: "${DAIMOS_REPO:?DAIMOS source tree required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1672-meminfo-native.XXXXXX")
keep=${KEEP_TEST:-0}
trap 'if [ "$keep" = 1 ]; then echo "v1672 native evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/syscall_info.s" "$work" <<'PY'
from pathlib import Path
import sys

source=Path(sys.argv[1]).read_text(encoding='ascii')
work=Path(sys.argv[2])
anchor='        movem   6,2(2)                 ; logical scheduler state\n'
last='        movem   6,3(2)                 ; logical user words\n'
start='sys_meminfo_proc_loop:\n'
if source.count(anchor)!=1 or source.count(last)!=1 or \
   source.count(start)!=1:
    raise SystemExit('v1672: real assembler source extraction drift')
proc=source.split(anchor,1)[1].split(last,1)[0]+last
mem=start+source.split(start,1)[1]
if 'cain    6,0777777\n' not in proc or \
   'cain    7,0777777\n' not in mem or \
   'jrst    sys_meminfo_proc_next\n' not in mem:
    raise SystemExit('v1672: native sentinel guards missing')
prefix=('.text\n'
        '.equ PROC_WORDS,3\n'
        '.equ PROC_STATE_LH_MASK,0700000\n'
        '.equ PROC_UAREA_RH,0400000\n'
        '.equ PROC_UAREA_WORDS,0410\n'
        '.globl v1672_procinfo_words_test\n'
        'v1672_procinfo_words_test:\n')
middle=('        popj    17,\n'
        '.globl sys_meminfo_proc_loop\n')
normal=prefix+proc+middle+mem
(work/'source-native.s').write_text(normal,encoding='ascii')
unsafe_proc=normal.replace('        cain    6,0777777\n'
                                '        setz    6,\n','',1)
(work/'unsafe-procinfo.s').write_text(unsafe_proc,encoding='ascii')
unsafe_mem=normal.replace('        cain    7,0777777\n'
                               '        jrst    sys_meminfo_proc_next\n','',1)
(work/'unsafe-meminfo.s').write_text(unsafe_mem,encoding='ascii')
PY

runner="$PDP10_PREFIX/bin/p10run"
for case_name in source-native unsafe-procinfo unsafe-meminfo; do
    if "$runner" --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 30 --workdir "$work/$case_name" \
        --name "meminfo-v1672-$case_name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/$case_name.s" "$here/test-meminfo-native-v1672.s" \
        > "$work/$case_name.log" 2>&1; then
        if [ "$case_name" != source-native ]; then
            echo "FAIL v1672: unsafe $case_name sentinel check survived" >&2
            keep=1;exit 1
        fi
        echo 'v1672: production SYS_MEMINFO and PROCINFO native zombie PASS'
    else
        if [ "$case_name" = source-native ]; then
            tail -70 "$work/$case_name.log" >&2
            keep=1;exit 1
        fi
        grep -q '^FAIL: __test_exit: got ' \
            "$work/$case_name.log" || {
            tail -70 "$work/$case_name.log" >&2; keep=1; exit 1;
        }
        echo "v1672: executed unsafe $case_name zombie mutant rejected"
    fi
done
echo 'PASS v1672: original assembler zombie accounting and unsafe mutants'
