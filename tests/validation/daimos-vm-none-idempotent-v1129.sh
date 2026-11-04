#!/bin/sh
# Extract the unmodified production VM destroy leaf and execute on PDP-6.
# A formerly destroyed EXEC VM must never turn VM_NONE into an MM base.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-vm-none-idempotent-v1129.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
{
    printf '.text\n.globl vm_space_destroy\n'
    sed -n '/^vm_space_destroy:$/,/^\/\*\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" | sed '$d'
} > "$work/vm-leaf.s"
python3 - "$work/vm-leaf.s" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
source = p.read_text()
old = '''        camn    3,[-1]
        jrst    vm_space_destroy_detach'''
assert source.count(old) == 1, 'v1129: full VM_NONE sentinel guard drift'
(p.parent / 'unsafe-vm-sentinel.s').write_text(source.replace(
    old, '''        came    3,[-1]
        jrst    vm_space_destroy_detach''', 1))
old = '''vm_space_destroy_detach:
        move    1,(17)
        pushj   17,proc_swap_detach'''
assert source.count(old) == 1, 'v1129: backing detach stage drift'
(p.parent / 'unsafe-swap-skip.s').write_text(source.replace(
    old, '''vm_space_destroy_detach:
        move    1,(17)
        setz    1,''', 1))
PY
run_case() {
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 120000 --timeout 20 \
        --workdir "$work/run-$name" --name "vm-none-v1129-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$self/daimos-vm-none-idempotent-v1129.s" \
        > "$work/$name.log" 2>&1
}
if ! run_case positive "$work/vm-leaf.s"; then
    tail -65 "$work/positive.log" >&2
    exit 1
fi
for kind in unsafe-vm-sentinel unsafe-swap-skip; do
    if run_case "$kind" "$work/$kind.s"; then
        echo "v1129: unsafe $kind unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1129: real VM_NONE destroy/retry, exact no-MM/XIP and backing detach; two unsafe mutations rejected PASS'
