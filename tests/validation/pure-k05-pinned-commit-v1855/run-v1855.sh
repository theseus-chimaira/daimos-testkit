#!/bin/sh
# KCC-built original PDP-6 FULL: two real pins must be validated at commit.
set -eu
: "${DAIMOS_REPO:?source-built DAIMOS kernel checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-k05-pinned-commit-v1855.XXXXXX")
trap 'echo "v1855 original native PDP-6 evidence: $work"' EXIT HUP INT TERM
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381 -I$kit/tests/validation/pure-ram-prefix-v1384"

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 \
    -Dmm_unpin=mm_unpin_fault_v1395 \
    -Dmm_pure_rebase_pinned_v1381=mm_pure_rebase_fault_v1397 \
    $inc -S "$src/proc/proc_pure_ram_v1381.c" \
    -o "$work/drop.s" >"$work/drop-compile.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PREFIX_V1384=1 $inc \
    -S "$src/proc/proc_pure_restore_v1384.c" \
    -o "$work/prefix.s" >"$work/prefix-compile.log" 2>&1

compile_full()
{
    input=$1
    output=$2
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -DDAIMOS_PURE_FULL_V1391=1 \
        -Dmm_unpin=mm_unpin_fault_v1395 \
        -Dmm_free=mm_free_reply_v1839 \
        -Dmm_alloc_aligned_noreclaim=mm_alloc_fault_v1855 \
        $inc -S "$input" -o "$output" \
        >"$work/full-compile.log" 2>&1 || {
            tail -60 "$work/full-compile.log" >&2
            exit 1
        }
}
compile_full "$src/proc/proc_pure_ram_restore_v1391.c" "$work/full.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$kit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1839\n'
    cat "$kit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
    printf '#undef main\n'
    printf '#define main baseline_main_v1855\n'
    cat "$kit/tests/validation/pure-full-free-reply-v1839/test-native-v1839.c"
    printf '#undef main\n'
    cat "$here/test-native-v1855.c"
} >"$work/test.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$work/test.c" -o "$work/test.s" \
    >"$work/test-compile.log" 2>&1 || {
        tail -65 "$work/test-compile.log" >&2
        exit 1
    }
run_guest()
{
    name=$1
    full=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "pure-k05-pinned-commit-v1855-$name" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/drop.s" "$work/prefix.s" "$full" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" "$work/test.s" \
        >"$work/$name.log" 2>&1
}
if ! run_guest accepted "$work/full.s"; then
    tail -80 "$work/accepted.log" >&2
    exit 1
fi
echo 'PASS v1855: real KCC PDP-6 accepted complete baseline, persistent allocator refusal, source/target extra-pin quarantine'

python3 "$here/mutate-v1855.py" \
    "$src/proc/proc_pure_ram_restore_v1391.c" \
    "$work/unsafe-no-guard.c" "$work/unsafe-weak-pin.c"
for spec in 'unsafe-no-guard 000000002002' \
    'unsafe-weak-pin 000000002002'; do
    set -- $spec
    compile_full "$work/$1.c" "$work/$1.s"
    if run_guest "$1" "$work/$1.s"; then
        echo "FAIL v1855: executed $1 mutant wrongly accepted" >&2
        exit 1
    fi
    if ! grep -q "^FAIL: __test_exit: got $2 " "$work/$1.log"; then
        tail -75 "$work/$1.log" >&2
        echo "FAIL v1855: $1 did not reach exact overpin oracle $2" >&2
        exit 1
    fi
    echo "PASS v1855: native unsafe $1 rejected at octal $2"
done
echo 'PASS v1855: original native FULL commit, persistent pressure and both executed unsafe controls'
