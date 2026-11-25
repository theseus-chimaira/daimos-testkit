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
work=$(mktemp -d "$TMPDIR/pure-terminal-finalizer-v1920.XXXXXX")
trap 'echo "v1920 integrated evidence: $work"' EXIT
python3 "$kit/tests/validation/pure-terminal-finalizer-v1681/build-native-v1681.py" "$DAIMOS_REPO" "$kit" "$work"
python3 "$kit/tests/validation/pure-parent-helper-v1807/extract-v1807.py" "$DAIMOS_REPO" "$work/parent.s"
python3 "$kit/tests/validation/pure-pi-leaves-v1807/extract-v1807.py" "$DAIMOS_REPO" "$work/pi.s"
python3 - "$here" "$work" <<'PY'
from pathlib import Path
import sys
here, work=map(Path,sys.argv[1:])
p=work/'test-fixture.s'; s=p.read_text()
a='        movei 1,050400\n        pushj 17,mm_pin\n'; b='fail_1_v1681:'
assert s.count(a)==1 and s.count(b)==1
s=s[:s.index(a)]+(here/'test-finalizer-v1920.s').read_text()+'\n'+s[s.index(b):]
s+='''\n.data
__free_calls_v1920: .word 0
.text
.globl mm_free
mm_free:
        aos     __free_calls_v1920
        pushj   17,mm_free_original_v1920
        jumpn   1,mm_free_return_v1920
        ; The real deletion committed. Simulate an inconsistent reply
        ; with a foreign claim in the original range. Never alter the
        ; original free instructions or fabricate an MM success.
        movei   4,1
        movem   4,mm_extent_count
        move    4,[0200,,050600]
        movem   4,mm_extents
        move    4,[2,,3]
        movem   4,mm_extents+1
        movni   1,5
mm_free_return_v1920:
        popj    17,
'''
p.write_text(s)
p=work/'original-mm.s'; s=p.read_text(); assert s.count('mm_free:\n')==1
p.write_text(s.replace('.globl mm_free\n','.globl mm_free_original_v1920\n').replace('mm_free:\n','mm_free_original_v1920:\n'))
p=work/'original-finalizer.s'; s=p.read_text(); a='        ior     4,5\n        pushj   17,proc_finish_mark_pending_v892'; assert s.count(a)==1
(work/'unsafe-finalizer.s').write_text(s.replace(a,'        pushj   17,proc_finish_mark_pending_v892'))
PY
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$src/proc/vm_pdp6_swap.c" -o "$work/detach.s" > "$work/compile.log" 2>&1
run_guest() {
    name=$1
    finalizer=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 350000 --timeout 45 --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$finalizer" "$work/original-vm-destroy.s" "$work/parent.s" "$work/pi.s" "$work/original-mm.s" "$work/original-pure-term.s" "$work/detach.s" "$src/mm/mm_pure_rebase_v1381.s" "$src/proc/proc_storage_runtime_v30.s" "$work/term-entry.s" "$work/test-fixture.s"
}
run_guest pure-terminal-finalizer-v1920 "$work/original-finalizer.s"
if run_guest unsafe-escrow-v1920 "$work/unsafe-finalizer.s" > "$work/unsafe.log" 2>&1; then
    echo 'FAIL: PREVM lost escrow accepted' >&2; exit 1
fi
grep -F 'FAIL: __test_exit: got 000000000005 ' "$work/unsafe.log" || { cat "$work/unsafe.log"; exit 1; }
echo 'PASS v1920 original MM + FINALIZE/PREVM exact escrow, unsafe escrow loss rejected'
