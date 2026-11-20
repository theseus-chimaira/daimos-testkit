#!/bin/sh
# Prove the actual VM destructor never repeats a completed MM release.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-vm-retire-v1695.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    printf 'K01 debug files: %s\n' "$work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
vm="$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s"
{
    printf '%s\n' '.text' '.globl vm_space_destroy'
    sed -n '/^vm_space_destroy:$/,/^\/\*\*$/p' "$vm" | sed '$d'
} > "$work/production.s"
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
anchor = ('        move    2,-1(17)\n'
          '        setom   1(2)\n'
          'vm_space_destroy_detach:')
assert source.count(anchor) == 1, 'early VM_NONE publication changed'
Path(sys.argv[2]).write_text(source.replace(
    anchor, 'vm_space_destroy_detach:', 1))
PY
run()
{
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 160000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-vm-retire-v1695-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-vm-retire-v1695.s" "$leaf" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -40 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1695: unsafe repeated MM release unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1695: native PDP-6 MM refusal, VM retirement, detach retry, no double-free and mutant PASS'
