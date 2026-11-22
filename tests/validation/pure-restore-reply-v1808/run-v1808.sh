#!/bin/sh
# Source-linked PDP-6 K05 positive and negative lost-reply regression.
set -eu
: "${DAIMOS_REPO:?integrated DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-pure-restore-reply-v1808.XXXXXX")
trap 'echo "v1808 source-linked evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381"
for spec in \
    'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' \
    'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384' \
    'proc_pure_ram_restore_v1391 DAIMOS_PURE_FULL_V1391'; do
    set -- $spec
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$2"=1 $inc -S "$src/proc/$1.c" \
        -o "$work/$1.s" >"$work/$1.log" 2>&1 || {
        tail -55 "$work/$1.log" >&2; exit 1;
    }
done
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$kit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1808\n'
    cat "$kit/tests/validation/pure-service-v1611/test-native-v1611.c"
    printf '#undef main\n'
    cat "$here/test-native-v1808.c"
} >"$work/native-v1808.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_PURE_SERVICE_V1612=1 \
    -Dproc_pure_mres_reclaim_v1611=proc_pure_mres_reclaim_v1612 \
    -Dproc_pure_mres_service_v1611=proc_pure_mres_service_v1612 \
    $inc -S "$work/native-v1808.c" -o "$work/native-v1808.s" \
    >"$work/native-v1808.log" 2>&1 || {
    tail -65 "$work/native-v1808.log" >&2; exit 1;
}
run_case()
{
    name=$1
    service=$2
    mkdir -p "$work/$name"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "pure-restore-reply-v1808-$name" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/proc_pure_ram_v1381.s" \
        "$work/proc_pure_restore_v1384.s" \
        "$work/proc_pure_ram_restore_v1391.s" \
        "$service" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" \
        "$work/native-v1808.s" >"$work/$name.log" 2>&1
}
compile_service()
{
    source=$1
    output=$2
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -Dproc_pure_restore_v1384=prefix_restore_reply_v1808 \
        -Dproc_pure_ram_restore_v1391=full_restore_reply_v1808 \
        $inc -S "$source" -o "$output" \
        >"$work/service-compile.log" 2>&1 || {
        tail -65 "$work/service-compile.log" >&2; exit 1;
    }
}
compile_service "$src/proc/proc_pure_service_pdp6_v1612.c" \
    "$work/real-service.s"
if ! run_case accepted "$work/real-service.s"; then
    tail -65 "$work/accepted.log" >&2
    echo 'FAIL v1808: source-linked lost-success restore' >&2
    exit 1
fi
echo 'PASS v1808: real prefix/FULL commits survive lost-success replies'
# Restore the former reply-only gate in a disposable source copy; the
# native guest must fail on READY_ONCE despite valid physical MM ownership.
python3 - "$src/proc/proc_pure_service_pdp6_v1612.c" \
    "$work/unsafe-old-gate.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding="ascii")
old = "        if (!PROC_TRANSITION(p) && VM_PDP6_BASE(p) &&\n"
new = "        if (rc == MM_OK && !PROC_TRANSITION(p) && VM_PDP6_BASE(p) &&\n"
if s.count(old) != 1:
    raise SystemExit("v1808 source gate drifted")
Path(sys.argv[2]).write_text(s.replace(old, new, 1), encoding="ascii")
PY
compile_service "$work/unsafe-old-gate.c" "$work/unsafe-old-gate.s"
if run_case unsafe-old-gate "$work/unsafe-old-gate.s"; then
    echo 'FAIL v1808: old reply-only gate accepted' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got 000000002004 ' \
    "$work/unsafe-old-gate.log"; then
    tail -65 "$work/unsafe-old-gate.log" >&2
    echo 'FAIL v1808: old gate rejected for wrong reason' >&2
    exit 1
fi
echo 'PASS v1808: original lost-reply regression mutant rejected at 02004'
