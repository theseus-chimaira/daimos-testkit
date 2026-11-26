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
work=$(mktemp -d "$TMPDIR/pure-mutable-admission-v1976.XXXXXX")
trap 'echo "v1976 admission evidence: $work"' EXIT
for name in "$src/proc/vm_pdp6_swap.c" "$here/test-native-v1976.c"; do
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -I"$src/proc" -I"$src/core" -I"$src/fs" -I"$src/mm" \
        -I"$src/storage" -I"$src/drivers" -I"$src/modules" \
        -I"$src/ipc" -I"$PDP10_PREFIX/include" -S "$name" \
        -o "$work/$(basename "$name" .c).s"
done
# FULL bridge dependencies are not used in this header/attach test.
cat > "$work/stub.s" <<'ASM'
.text
.globl proc_swap_unpack_backing
proc_swap_unpack_backing:
        setz 1,
        popj 17,
ASM
run_guest() {
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 --workdir "$work/$1" \
        --name "$1" --expect __test_exit=0 --examine diag_case_v1976 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$2" \
        "$src/proc/exec_image_common_v1386.s" "$work/stub.s" \
        "$work/vm_pdp6_swap.s" "$work/test-native-v1976.s"
}
run_guest admission-v1976 "$src/proc/exec_load.s"
# Remove the real approval check; the native oracle must reject this mutant.
python3 - "$src/proc/exec_load.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a='        skipe   -003(17)               ; only administrator-approved file\n        jrst    exec_load_fail\n'
assert s.count(a)==1
Path(sys.argv[2]).write_text(s.replace(a,''))
PY
if run_guest admission-unsafe-v1976 "$work/unsafe.s" >"$work/unsafe.log" 2>&1; then
    echo 'FAIL: unsafe privilege mutant accepted'; exit 1
fi
grep '^FAIL: __test_exit: got ' "$work/unsafe.log"
