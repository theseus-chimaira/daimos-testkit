#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-terminal-v1920.XXXXXX")
trap 'echo "v1920 evidence: $work"' EXIT
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"
python3 - "$kit/tests/validation/pure-ram-teardown-v1609/test-native-v1609.c" "$here/test-native-v1920.c" "$work/test.c" <<'PY'
from pathlib import Path
import sys
base, test, dest = map(Path, sys.argv[1:])
s=base.read_text()
def once(old,new):
    global s
    assert s.count(old)==1,old
    s=s.replace(old,new,1)
once('int\nmm_free(kword_t base, unsigned int type, unsigned int owner)\n','static unsigned int terminal_fault_v1920;\nint\nmm_free(kword_t base, unsigned int type, unsigned int owner)\n')
once('if (type != MM_TYPE_PACKED_PROCESS ||','if ((type != MM_TYPE_PACKED_PROCESS && type != MM_TYPE_PROCESS) ||')
once('                for (; i + 1 < mm_extent_count; ++i)','''                if (terminal_fault_v1920 == 2U)
                        return MM_OK;
                if (terminal_fault_v1920 == 3U) {
                        mm_extents[i].meta = (mm_extents[i].meta & ~MM_OWNER_MASK) | 2U;
                        return MM_ERR_BUSY;
                }
                for (; i + 1 < mm_extent_count; ++i)''')
once('                --mm_extent_count;\n                return MM_OK;','''                --mm_extent_count;
                if (terminal_fault_v1920 == 4U) {
                        mm_extents[0].span = (0200UL << 18U) | (base + 0200UL);
                        mm_extents[0].meta = ((kword_t)MM_TYPE_MODULE << MM_TYPE_SHIFT) | 2U;
                        mm_extent_count = 1;
                } else if (terminal_fault_v1920 == 5U)
                        mm_extent_count = MM_MAX_EXTENTS + 1;
                return terminal_fault_v1920 ? MM_ERR_BUSY : MM_OK;''')
once('int\nmain(void)\n','int\nhistorical_main_v1920(void)\n')
dest.write_text(s+'\n'+test.read_text())
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$src/proc/vm_pdp6_swap.c" -o "$work/swap.s" >"$work/swap.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$work/test.c" -o "$work/test.s" >"$work/test.log" 2>&1
{ printf '.text\n.globl vm_space_destroy\n'; sed -n '/^vm_space_destroy:$/,/^\/\*\*$/p' "$src/proc/vm_pdp6.s" | sed '$d'; } > "$work/vm.s"
{ printf '.equ PROC_SWAP_TEXT_SHIFT,026\n.equ PROC_SWAP_TEXT_MASK,037777\n.equ PROC_SWAP_BACKING_OFFSET,0406\n.equ EXEC_USER_ORIGIN,020\n'; cat "$src/proc/proc_pure_packed_detach_v1609.s"; } > "$work/terminal.s"
printf '.text\n.globl proc_swap_term_v1666\nproc_swap_term_v1666:\n        jrst pdp6_pure_detach_v1609\n' > "$work/entry.s"
run_guest() {
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/swap.s" "$work/vm.s" "$work/entry.s" "$leaf" "$src/core/ret.s" "$src/proc/proc_storage_runtime_v30.s" "$src/drivers/device_state.s" "$work/test.s"
}
run_guest pure-terminal-v1920 "$work/terminal.s"
echo 'PASS v1920 23 terminal owner cases'
# Every unsafe variant must fail a real guest assertion.
python3 - "$work/terminal.s" "$work" <<'PY'
from pathlib import Path
import sys
p, work = map(Path, sys.argv[1:])
s=p.read_text()
mutants={
    'unsafe-marker': ('        tlne    6,040000               ; nonterminal retry/escrow\n        jrst    ppure_detach_bad_early_v1900', '        move    6,6'),
    'unsafe-geometry': ('        camge   7,012                   ; sorted and nonoverlapping\n        jrst    ppure_detach_scan_bad_v1920', '        move    7,7'),
    'unsafe-success': ('        movei   0,2\n        pushj   17,ppure_detach_scan_v1920\n        jumpn   1,ppure_detach_bad_v1609', '        jumpe   1,ppure_detach_publish_v1900\n        movei   0,2\n        pushj   17,ppure_detach_scan_v1920\n        jumpn   1,ppure_detach_bad_v1609'),
    'unsafe-replacement': ('        came    7,016                   ; never adopt a replacement\n        jrst    ppure_detach_scan_bad_v1920', '        move    7,7'),
    'unsafe-post-overlap': ('        camle   012,016\n        jrst    ppure_detach_scan_bad_v1920', '        move    012,012'),
}
for name,(old,new) in mutants.items():
    assert s.count(old)==1,name
    (work/(name+'.s')).write_text(s.replace(old,new,1))
PY
for name in unsafe-marker unsafe-geometry unsafe-success unsafe-replacement unsafe-post-overlap; do
    if run_guest "$name" "$work/$name.s" > "$work/$name.log" 2>&1; then
        echo "FAIL: $name accepted" >&2; exit 1
    fi
    grep -F 'FAIL: __test_exit' "$work/$name.log" || { cat "$work/$name.log"; exit 1; }
    echo "PASS: $name rejected"
done
