#!/bin/sh
# Execute original staged DROP/PREFIX/FULL and the new source-linked MRES
# on the PDP-6 simulator. Only FS source and test MM pressure are fixtures.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
service=proc_pure_service_pdp6_v1611.c
test_flags=
tag=v1611
if [ "${DAIMOS_TEST_PURE_SERVICE_V1612:-0}" = 1 ]; then
    service=proc_pure_service_pdp6_v1612.c
    tag=v1612
    test_flags='-DDAIMOS_TEST_PURE_SERVICE_V1612=1 -Dproc_pure_mres_reclaim_v1611=proc_pure_mres_reclaim_v1612 -Dproc_pure_mres_service_v1611=proc_pure_mres_service_v1612'
fi
work=$(mktemp -d "$TMPDIR/pure-service-$tag.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" = 1 ]; then echo "$tag work: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"

for spec in \
    'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' \
    'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384' \
    'proc_pure_ram_restore_v1391 DAIMOS_PURE_FULL_V1391'; do
    set -- $spec
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$2"=1 $inc -S "$src/proc/$1.c" \
        -o "$work/$1.s" >"$work/$1.log" 2>&1 || {
        cat "$work/$1.log"
        exit 1
    }
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    $inc -S "$src/proc/$service" \
    -o "$work/service-v1611.s" >"$work/service.log" 2>&1 || {
    cat "$work/service.log"
    exit 1
}
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    cat "$here/test-native-v1611.c"
} >"$work/test-v1611.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    $test_flags $inc -S "$work/test-v1611.c" \
    -o "$work/test-v1611.s" >"$work/test.log" 2>&1 || {
    cat "$work/test.log"
    exit 1
}
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-service-v1611 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1381.s" \
    "$work/proc_pure_restore_v1384.s" \
    "$work/proc_pure_ram_restore_v1391.s" \
    "$work/service-v1611.s" \
    "$src/mm/mm_pure_rebase_v1381.s" \
    "$src/mm/mm_pure_expand_v1384.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-v1611.s"

# Source-authentic negative: bypass the final readiness guard only in a
# private copy. The executed PDP-6 guest must reject READY_ONCE on IO failure.
python3 - "$src/proc/$service" \
    "$work/unsafe-ready-v1611.c" "$tag" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old_v1611 = '''        if (rc == MM_OK &&
            !PROC_TRANSITION(p) && VM_PDP6_BASE(p) &&
            proc_storage_expect_v30(slot, PROC_STORAGE_RESIDENT) == 0) {
'''
old_v1612 = '''        if (!PROC_TRANSITION(p) && VM_PDP6_BASE(p) &&
            proc_storage_expect_v30(slot, PROC_STORAGE_RESIDENT) == 0) {
'''
old = old_v1612 if sys.argv[3] == "v1612" else old_v1611
assert s.count(old) == 1, 'v1611/v1612: ready publication anchor drift'
Path(sys.argv[2]).write_text(s.replace(old, '        if (1) {\n', 1))
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$work/unsafe-ready-v1611.c" \
    -o "$work/unsafe-ready-v1611.s" \
    >"$work/unsafe-compile.log" 2>&1 || {
    cat "$work/unsafe-compile.log"
    exit 1
}
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/unsafe" --name pure-unsafe-ready-v1611 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1381.s" \
    "$work/proc_pure_restore_v1384.s" \
    "$work/proc_pure_ram_restore_v1391.s" \
    "$work/unsafe-ready-v1611.s" \
    "$src/mm/mm_pure_rebase_v1381.s" \
    "$src/mm/mm_pure_expand_v1384.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-v1611.s" >"$work/unsafe-run.log" 2>&1; then
    echo 'FAIL v1611: unsafe READY_ONCE publication was accepted' >&2
    exit 1
fi
if ! grep -F 'FAIL: __test_exit' "$work/unsafe-run.log" >/dev/null; then
    cat "$work/unsafe-run.log"
    echo 'FAIL v1611: mutant failed for a non-assertion reason' >&2
    exit 1
fi
echo "PASS $tag native RAW DROP, prefix/FULL, refusal and unsafe READY mutant"
