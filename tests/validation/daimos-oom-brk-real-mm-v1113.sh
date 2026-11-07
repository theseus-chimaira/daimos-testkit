#!/bin/sh
# v1113: genuine PDP-6 MM refusal propagated through real VM and BRK.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-brk-real-mm-v1113.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1113: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import os
import sys

root = Path(sys.argv[1]) / 'system/kernel'
work = Path(sys.argv[2])
mm = (root / 'mm/mm_pdp6.s').read_text()
vm = (root / 'proc/vm_pdp6.s').read_text()
sc = (root / 'proc/syscall_dispatch_pdp6.s').read_text()

def section(source, first, last):
    assert source.count(first) == 1 and source.count(last) == 1, first
    return first + source.split(first, 1)[1].split(last, 1)[0]

mm_code = (section(mm, 'mm_extent_insert:\n', '\n; AC1=base.') +
           section(mm, 'mm_find_fit:\n',
                   '\n; int mm_alloc_aligned_noreclaim') +
           section(mm, 'mm_alloc_aligned_noreclaim:\n',
                   '\n; Move one process extent') +
           section(mm, 'mm_compact:\n', '\n; int mm_alloc(words') +
           # v1260 added a real, read-only arena-capacity preflight
           # referenced by the production aligned allocator. Extract
           # that exact native leaf, not a fabricated constant-success
           # stub: the isolated v1113 fixture must retain production
           # MM error typing and its false-OOM negative controls.
           section(mm, 'mm_arena_fits_v1260:\n',
                   '\n; int mm_alloc_aligned(words,align,type,owner,preference,basep)\nmm_alloc_aligned:') +
           section(mm, 'mm_alloc_aligned:\n', '\n; int mm_free('))
vm_code = section(vm, 'vm_space_brk_current:\n',
                  '\n/**\n * @brief Allocate and clear one aligned')
sc_code = section(sc, 'native_sys_brk:\n', '\n; Root may rebind')
off = '.equ    PROC_OOM_BRK_ENABLED_V1000,0'
on = '.equ    PROC_OOM_BRK_ENABLED_V1000,1'
expected = os.environ.get('V1283_PRODUCTION_OOM_DEFAULT', '0')
assert expected in ('0', '1'), 'invalid production OOM expectation'
assert sc_code.count(off) + sc_code.count(on) == 1
gate = off if expected == '0' else on
assert sc_code.count(gate) == 1, 'unexpected production OOM policy'
sc_code = sc_code.replace(gate, on, 1)

header = ('.text\n.globl native_sys_brk\n.globl vm_space_brk_current\n'
          '.globl mm_alloc_aligned\n.globl mm_alloc_aligned_noreclaim\n'
          '.globl mm_find_fit\n.globl mm_compact\n'
          '.globl mm_arena_fits_v1260\n'
          '.equ MM_TYPE_PROCESS,1\n.equ MM_ALLOC_LOW,0\n'
          '.equ MM_ERR_FRAGMENTED,-2\n.equ MM_TYPE_KERNEL_DYNAMIC,3\n'
          '.equ PROC_NO_SLOT,0400\n.equ VM_EXTENT_ALIGN_WORDS,02000\n')
body = header + mm_code + vm_code + sc_code
(work / 'production.s').write_text(body)

mutants = {
    'lost-vm-cause': (vm_code,
                      '        move    2,1                     ; exact allocator failure cause',
                      '        seto    2,                     ; unsafe false OOM'),
    'lost-fragmentation': (mm_code,
                           '        movni   1,2\n        jrst    mm_alloc_nr_return',
                           '        seto    1,\n        jrst    mm_alloc_nr_return'),
    'lost-descriptors': (mm_code,
                         'mm_alloc_nr_descriptors:\n        movni   1,3',
                         'mm_alloc_nr_descriptors:\n        seto    1,'),
}
for name, (part, before, after) in mutants.items():
    assert part.count(before) == 1, name
    (work / ('unsafe-' + name + '.s')).write_text(
        body.replace(before, after, 1))
PY
run_case() {
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 400000 --timeout 25 \
        --workdir "$work/run-$name" --name "oom-real-mm-v1113-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$source" "$self/daimos-oom-brk-real-mm-v1113.s" \
        > "$work/log-$name" 2>&1
}
run_case production "$work/production.s" || {
    tail -55 "$work/log-production" >&2
    exit 1
}
for mutant in lost-vm-cause lost-fragmentation lost-descriptors; do
    if run_case "$mutant" "$work/unsafe-$mutant.s"; then
        echo "v1113: unsafe $mutant passed" >&2
        exit 1
    fi
done
echo 'v1113: real MM -2/-3 via VM BRK and fatal-enabled syscall, three mutants rejected PASS'
