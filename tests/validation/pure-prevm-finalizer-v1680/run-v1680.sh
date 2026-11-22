#!/bin/sh
# Linked ORIGINAL PDP-6 finalizer, modeled VM pin pressure at its boundary.
set -eu
: "${DAIMOS_REPO:?source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-prevm-finalizer-v1680.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1680 finalizer evidence: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$kit/tests/validation/daimos-deferred-uarea-v881.s" "$work" \
    "$here/test-native-v1680.s" <<'PY'
from pathlib import Path
import sys
source, fixture, work, test = map(Path, sys.argv[1:])
text = source.read_text(encoding="ascii")
first = "proc_finish_slot:\n"
last = "\nproc_slot_discard:\n"
if text.count(first) != 1 or last not in text.split(first, 1)[1]:
    raise ValueError("original PDP-6 PREVM finalizer boundaries drifted")
header = """.text
.globl proc_finish_slot
.globl proc_finish_service_v881
.equ PROC_WORDS,3
.equ PROC_TRANSITION_RH,0200000
.equ PROC_STATE_LH_MASK,0700000
.equ PROC_FILE_TABLE_OFFSET,026
.equ PROC_FDCTL_OFFSET,024
.equ PROC_FINALIZE_OFFSET,067
.equ PROC_FINALIZE_MARK_LH,0400000
.equ PROC_FINALIZE_PREVM_LH,0100000
.equ PROC_FATAL_CLOSE_BIT,4
.equ CTX_PC,020
.equ PROC_WAIT_LH_MASK,060000
"""
leaf = header + first + text.split(first, 1)[1].split(last, 1)[0]
(work / "production-v1680.s").write_text(leaf, encoding="ascii")
fixture = fixture.read_text(encoding="ascii")
fixture = fixture[fixture.index(".globl proc_session_teardown\n"):]
old = """vm_space_destroy:
 aos __vm_calls
 setom 1(1)
 setz 1,
 popj 17,"""
new = """vm_space_destroy:
 aos __vm_calls
 skipn __vm_pins_v1680
 jrst vm_unpinned_v1680
 seto 1,
 popj 17,
vm_unpinned_v1680:
 setom 1(1)
 setz 1,
 popj 17,"""
if fixture.count(old) != 1:
    raise ValueError("source fixture modeled VM refusal anchor drift")
fixture = fixture.replace(old, new, 1)
fixture += "\n.data\n.globl __vm_pins_v1680\n__vm_pins_v1680: .word 0\n"
(work / "driver-v1680.s").write_text(
    test.read_text(encoding="ascii") + "\n" + fixture,
    encoding="ascii")
mutant_old = "        jumpe   1,proc_finish_vm_done"
mutant_new = "        jrst    proc_finish_vm_done"
if leaf.count(mutant_old) != 1:
    raise ValueError("original VM success publication gate drift")
(work / "unsafe-v1680.s").write_text(
    leaf.replace(mutant_old, mutant_new, 1), encoding="ascii")
PY
run_case() {
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 600000 --timeout 30 \
        --workdir "$work/$name" --name "pure-prevm-v1680-$name" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$leaf" \
        "$work/driver-v1680.s" \
        >"$work/$name.log" 2>&1
}
if ! run_case accepted "$work/production-v1680.s"; then
    tail -70 "$work/accepted.log" >&2
    exit 1
fi
echo 'PASS v1680: real PDP6 finalizer/idle PREVM preserves pinned VM through 4 refusals'
if run_case unsafe "$work/unsafe-v1680.s"; then
    echo 'FAIL v1680: unsafe early VM publication accepted' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got ' "$work/unsafe.log"; then
    tail -70 "$work/unsafe.log" >&2
    exit 1
fi
echo 'PASS v1680: executed premature PREVM publication mutant rejected'
