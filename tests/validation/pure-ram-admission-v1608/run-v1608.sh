#!/bin/sh
# v1608 P1-E1: source-backed no-disk and executable mount admission.
# Include real PDP-6 KCC/MM/drop/restore regressions and reject a
# deliberately unsafe source mutation without modifying DAIMOS.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-admission-v1608.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel"
for suite in inplace-v1381 backing-v1382 prefix-v1384 prefix-v1385 \
    full-backing-v1390 rollback-v1395; do
    case "$suite" in
    inplace-v1381) ver=1381 ;;
    backing-v1382) ver=1382 ;;
    prefix-v1384) ver=1384 ;;
    prefix-v1385) ver=1385 ;;
    full-backing-v1390) ver=1390 ;;
    rollback-v1395) ver=1395 ;;
    esac
    case "$suite" in
    full-backing-v1390)
        runner="$testkit/tests/validation/exec-image-full-backing-v1390/run-v1390.sh"
        ;;
    *)
        runner="$testkit/tests/validation/pure-ram-$suite/run-v$ver.sh"
        ;;
    esac
    sh "$runner" > \
        "$work/$suite.log" 2>&1 || {
        cat "$work/$suite.log"
        exit 1
    }
    echo "PASS v1608 prerequisite $suite"
done

# A missing admission check is a real reject, not a harmless
# documentation discrepancy. Replace the one actual C invocation
# only in a private test candidate and execute it with the same
# source-linked native 36-bit-word ownership fixture.
original="$src/proc/proc_pure_ram_v1381.c"
mutant="$work/proc_pure_ram_mutant_v1608.c"
sed 's/rc = pure_admit_source_v1608(p, backing);/rc = MM_OK;/' \
    "$original" > "$mutant"
if cmp -s "$mutant" "$original"; then
    echo 'FAIL: admission mutation was not applied' >&2
    exit 1
fi
includes="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 $includes \
    -S "$mutant" -o "$work/proc-pure-mutant-v1608.s" > \
    "$work/mutant-compile.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    $includes -S \
    "$testkit/tests/validation/pure-ram-inplace-v1381/test-native-v1381.c" \
    -o "$work/test-native-v1608.s" > "$work/test-compile.log" 2>&1
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/mutant-guest" --name pure-admission-mutant-v1608 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc-pure-mutant-v1608.s" \
    "$src/mm/mm_pure_rebase_v1381.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-native-v1608.s" > "$work/mutant-run.log" 2>&1; then
    echo 'FAIL: unsafe P1-E1 admission bypass was accepted' >&2
    exit 1
fi
if ! grep -F 'FAIL: __test_exit' "$work/mutant-run.log" >/dev/null; then
    cat "$work/mutant-run.log"
    echo 'FAIL: mutant failed for a reason other than admission' >&2
    exit 1
fi
echo 'PASS P1-E1 v1608: no-backing/mount admission and mutation rejection'
