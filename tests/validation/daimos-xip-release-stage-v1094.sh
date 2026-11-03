#!/bin/sh
# Real VM and MEMFS XIP release leaves; native PDP-6 fault-stage matrix.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-xip-release-v1094.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1094 work: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
work = Path(sys.argv[2])
vm = (root / 'system/kernel/proc/vm_pdp6.s').read_text()
mem = (root / 'system/kernel/fs/memfs_runtime.s').read_text()
vm_start = 'vm_space_destroy:'
vm_end = '/**\n * @brief Read executable words'
mem_start = 'memfs_mres_xip_release:'
mem_end = '; SPACE returns total'
for source, begin, end in ((vm, vm_start, vm_end),
                            (mem, mem_start, mem_end)):
    assert source.count(begin) == 1 and source.count(end) == 1
vm_leaf = vm.split(vm_start, 1)[1].split(vm_end, 1)[0]
mem_leaf = mem.split(mem_start, 1)[1].split(mem_end, 1)[0]
assert 'vm_space_destroy_xip_other_v1094:' in vm_leaf
assert 'camn    1,[-1]' in vm_leaf
assert 'movni   1,4' in mem_leaf
header = ('.text\n.globl vm_space_destroy\n'
          '.globl memfs_mres_xip_release\n')
def body(v, m):
    return (header + vm_start + v + '\n' + mem_start + m)
(work / 'leaves.s').write_text(body(vm_leaf, mem_leaf))
bad_error = mem_leaf.replace('        movni   1,4',
                             '        seto    1', 1)
(work / 'unsafe-error.s').write_text(body(vm_leaf, bad_error))
guard = ('        camn    1,[-1]\n'
         '        jrst    vm_space_destroy_maybe_process\n'
         '        jrst    vm_space_destroy_fail')
assert vm_leaf.count(guard) == 1
bad_guard = vm_leaf.replace(guard,
    '        camn    1,[-1]\n'
    '        jrst    vm_space_destroy_maybe_process\n'
    '        jrst    vm_space_destroy_maybe_process', 1)
(work / 'unsafe-fallback.s').write_text(body(bad_guard, mem_leaf))
bad_mm = vm_leaf.replace('        jumpn   1,vm_space_destroy_fail\n'
                             'vm_space_destroy_detach:',
                         '        jumpe   1,vm_space_destroy_fail\n'
                             'vm_space_destroy_detach:', 1)
assert bad_mm != vm_leaf
(work / 'unsafe-mm.s').write_text(body(bad_mm, mem_leaf))
bad_swap = vm_leaf.replace(
    '        jumpn   1,vm_space_destroy_fail  ; keep VM and swap record retryable',
    '        jumpe   1,vm_space_destroy_fail  ; unsafe detach commit', 1)
assert bad_swap != vm_leaf
(work / 'unsafe-swap.s').write_text(body(bad_swap, mem_leaf))
print('v1094: production VM/MEMFS release leaves and mutation anchors PASS')
PY
run_native() {
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 32000 --timeout 15 \
        --workdir "$work/run-$1" --name "xip-release-v1094-$1" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-xip-release-stage-v1094.s" "$2" \
        > "$work/log-$1" 2>&1
}
run_native positive "$work/leaves.s" || {
    tail -65 "$work/log-positive" >&2
    exit 1
}
for kind in error fallback mm swap; do
    if run_native "unsafe-$kind" "$work/unsafe-$kind.s"; then
        echo "v1094: unsafe $kind release unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1094: owned XIP/MM -4/-5, absent provider, VM/bitmap retry and four mutants PASS'
