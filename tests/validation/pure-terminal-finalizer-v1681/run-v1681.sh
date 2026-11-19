#!/bin/sh
# Original PDP-6 MM pin/unpin + RAW terminal + VM + FINALIZE+PREVM.
set -eu
: "${DAIMOS_REPO:?source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-terminal-finalizer-v1681.XXXXXX")
trap 'echo "v1681 original-instruction evidence: $work"' EXIT
python3 "$here/build-native-v1681.py" "$DAIMOS_REPO" "$kit" "$work"
src="$DAIMOS_REPO/system/kernel"
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$src/proc/vm_pdp6_swap.c" -o "$work/actual-detach.s" \
    >"$work/build-c.log" 2>&1 || { tail -65 "$work/build-c.log"; exit 1; }
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 35 \
    --workdir "$work/guest" --name pure-terminal-finalizer-v1681 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/original-finalizer.s" "$work/original-vm-destroy.s" \
    "$work/original-mm.s" "$work/original-pure-term.s" \
    "$work/actual-detach.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$work/term-entry.s" "$work/test-fixture.s" >"$work/guest.log" 2>&1 || {
    tail -65 "$work/guest.log"; exit 1;
}
echo 'PASS v1681: actual MM pin/unpin and source-linked FINALIZE+PREVM/PURE terminal retry'
# Executed mutations of original source, preserving all other real links.
# The same integrated test must reject incorrect PREVM or MM pin flow.
python3 - "$work/original-finalizer.s" "$work/original-mm.s" \
    "$work/unsafe-finalizer-commit.s" "$work/unsafe-no-prevm.s" \
    "$work/unsafe-mm-pin.s" "$work/unsafe-backoff.s" <<'PYV1681MUT'
from pathlib import Path
import sys
original = Path(sys.argv[1]).read_text(encoding="ascii")
mutants = (
    ("        pushj   17,vm_space_destroy\n"
     "        jumpe   1,proc_finish_vm_done",
     "        pushj   17,vm_space_destroy\n"
     "        jrst    proc_finish_vm_done", 3),
    ("        movsi   4,PROC_FINALIZE_MARK_LH+PROC_FINALIZE_PREVM_LH",
     "        movsi   4,PROC_FINALIZE_MARK_LH", 4),
)
for old, new, pos in mutants:
    if original.count(old) != 1:
        raise SystemExit("v1681 original FINALIZE mutation anchor changed")
    Path(sys.argv[pos]).write_text(original.replace(old, new, 1),
                                   encoding="ascii")
mm = Path(sys.argv[2]).read_text(encoding="ascii")
old = "        add     4,[MM_PIN_ONE]"
new = "        add     4,[0]  ; unsafe ignored MM pin increment"
if mm.count(old) != 1:
    raise SystemExit("v1681 original MM pin mutation anchor changed")
Path(sys.argv[5]).write_text(mm.replace(old, new, 1), encoding="ascii")
# Test the original shared backoff algorithm, rather than accepting an
# unconditional next-tick retry in the extracted finalizer service.
old = ("        caige   4,01000\n"
       "        lsh     4,1")
new = ("        caige   4,01000\n"
       "        move    4,4  ; unsafe no backoff advance")
if original.count(old) != 1:
    raise SystemExit("v1681 original backoff mutation anchor changed")
Path(sys.argv[6]).write_text(original.replace(old, new, 1),
                             encoding="ascii")
PYV1681MUT

run_mutant_v1681()
{
    name=$1
    finalizer=$2
    mm=$3
    expected=$4
    log="$work/mutant-$name.log"
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 350000 --timeout 35 \
        --workdir "$work/mutant-$name" --name "pure-unsafe-$name-v1681" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$finalizer" "$work/original-vm-destroy.s" \
        "$mm" "$work/original-pure-term.s" \
        "$work/actual-detach.s" "$src/proc/proc_storage_runtime_v30.s" \
        "$work/term-entry.s" "$work/test-fixture.s" >"$log" 2>&1; then
        echo "FAIL v1681: unsafe original source $name passed" >&2
        exit 1
    fi
    if ! grep -q "^FAIL: __test_exit: got $expected " "$log"; then
        tail -55 "$log" >&2
        echo "FAIL v1681: $name mutant failed without exact oracle" >&2
        exit 1
    fi
    echo "PASS v1681: original $name mutant rejected at $expected"
}
run_mutant_v1681 false-vm-commit "$work/unsafe-finalizer-commit.s" \
    "$work/original-mm.s" 000000000006
run_mutant_v1681 missing-prevm "$work/unsafe-no-prevm.s" \
    "$work/original-mm.s" 000000000006
run_mutant_v1681 no-real-mm-pin "$work/original-finalizer.s" \
    "$work/unsafe-mm-pin.s" 000000000004
run_mutant_v1681 missing-backoff "$work/unsafe-backoff.s" \
    "$work/original-mm.s" 000000000035
