#!/bin/sh
# Original native PDP-6 ownership transaction and executed unsafe mutant.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-mm-owner-v1658.XXXXXX")
trap 'echo "v1658 native evidence: $work"' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"

sh "$testkit/tests/validation/pure-full-commit-v1654/run-v1654.sh" >"$work/v1654-baseline.log" 2>&1
sh "$testkit/tests/validation/pure-service-v1612/run-v1612.sh" >"$work/v1612-baseline.log" 2>&1
echo 'v1658: original FULL fault and source-linked service baselines PASS'

for spec in \
    'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' \
    'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384' \
    'proc_pure_ram_restore_v1391 DAIMOS_PURE_FULL_V1391'; do
    set -- $spec
    extra=
    if [ "$1" = proc_pure_ram_v1381 ]; then
        extra=-Dmm_unpin=mm_unpin_fault_v1658
    fi
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$2"=1 $extra $inc -S "$src/proc/$1.c" \
        -o "$work/$1.s" >"$work/$1.log" 2>&1 || {
        cat "$work/$1.log" >&2
        exit 1
    }
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$src/proc/proc_pure_service_pdp6_v1612.c" \
    -o "$work/service.s" >"$work/service.log" 2>&1 || {
    cat "$work/service.log" >&2
    exit 1
}
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1658\n'
    cat "$testkit/tests/validation/pure-service-v1611/test-native-v1611.c"
    printf '#undef main\n'
    cat "$here/test-native-v1658.c"
} >"$work/test.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_PURE_SERVICE_V1612=1 \
    -Dproc_pure_mres_reclaim_v1611=proc_pure_mres_reclaim_v1612 \
    -Dproc_pure_mres_service_v1611=proc_pure_mres_service_v1612 \
    $inc -S "$work/test.c" -o "$work/test.s" \
    >"$work/test.log" 2>&1 || {
    cat "$work/test.log" >&2
    exit 1
}

run_guest() {
    name=$1
    mmfile=$2
    target=$3
    mkdir -p "$work/$name"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/proc_pure_ram_v1381.s" \
        "$work/proc_pure_restore_v1384.s" \
        "$work/proc_pure_ram_restore_v1391.s" \
        "$work/service.s" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$mmfile" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" \
        "$work/test.s" >"$target" 2>&1
}

run_guest pure-mm-owner-v1658 "$src/mm/mm_pure_expand_v1384.s" \
    "$work/native-pass.log" || { tail -70 "$work/native-pass.log" >&2; exit 1; }
echo 'v1658: native atomic retype+unpin, DROP completed/refused owner PASS'

python3 - "$src/mm/mm_pure_expand_v1384.s" "$work/unsafe-pin.s" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
line = '        sub     4,[010000000]          ; consume exactly one verified pin\n'
if src.count(line) != 1:
    raise SystemExit('v1658 pin-consumption anchor changed')
Path(sys.argv[2]).write_text(src.replace(line, '', 1))
PY
if run_guest pure-mm-unsafe-v1658 "$work/unsafe-pin.s" \
    "$work/native-mutant.log"; then
    echo 'FAIL v1658: executed pin-leak mutant was accepted' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got ' "$work/native-mutant.log"; then
    tail -70 "$work/native-mutant.log" >&2
    echo 'FAIL v1658: mutant did not reach the native owner oracle' >&2
    exit 1
fi
echo 'v1658: executed unsafe post-commit retained-pin mutant rejected'
