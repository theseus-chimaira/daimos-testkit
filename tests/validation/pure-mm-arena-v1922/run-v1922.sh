#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-mm-arena-v1922.XXXXXX")
trap 'echo "v1922 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
compile -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 "$src/proc/proc_pure_restore_v1384.c" -o "$work/prefix.s"
compile -DDAIMOS_PURE_FULL_V1391=1 "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/full.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$kit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    cat "$here/test-native-v1922.c"
} > "$work/test.c"
compile "$work/test.c" -o "$work/test.s" > "$work/compile-test.log" 2>&1 || { cat "$work/compile-test.log"; exit 1; }
run_guest() {
    name=$1
    drop=$2
    full=$3
    rebase=${4:-$src/mm/mm_pure_rebase_v1381.s}
    expand=${5:-$src/mm/mm_pure_expand_v1384.s}
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$drop" "$work/prefix.s" "$full" "$rebase" "$expand" "$src/proc/proc_storage_runtime_v30.s" "$src/drivers/device_state.s" "$work/test.s"
}
run_guest pure-mm-arena-v1922 "$work/drop.s" "$work/full.s"
echo 'PASS v1922 18 arena, 12 table and 7 native mutation refusal cases'
# Native assertion-based mutants of the actual MM assembly.
python3 - "$src/mm" "$work" <<'PY'
from pathlib import Path
import sys
src, work = map(Path, sys.argv[1:])
s = (src/'mm_pure_rebase_v1381.s').read_text()
checks = {
    'unsafe-early-arena': ('        move    2,6                    ; containing arena\'s exclusive end\n', '        move    2,6\n        jrst    mpure_range_done_v1922\n'),
    'unsafe-range-end': ('        camle   3,6\n        jrst    mpure_range_next_v1922\n', ''),
    'unsafe-cached-end': ('        camg    011,012\n        jrst    mpure_table_next_v1922\n', '        jumpn   012,mpure_table_next_v1922\n'),
    'unsafe-table-order': ('        camge   1,011                  ; sorted, nonoverlapping\n        jrst    mpure_table_bad_v1922\n', ''),
}
for name,(old,new) in checks.items():
    assert s.count(old)==1,name
    (work/(name+'.s')).write_text(s.replace(old,new,1))
s=(src/'mm_pure_expand_v1384.s').read_text()
a='        pushj   17,mm_pure_range_v1922\n        came    1,[-2]'
assert s.count(a)==1
(work/'unsafe-prefix-range.s').write_text(s.replace(a,'        setz    1,\n        came    1,[-2]',1))
PY
for name in unsafe-early-arena unsafe-range-end unsafe-cached-end unsafe-table-order unsafe-prefix-range; do
    rebase=$work/$name.s
    expand=$src/mm/mm_pure_expand_v1384.s
    if [ "$name" = unsafe-prefix-range ]; then
        rebase=$src/mm/mm_pure_rebase_v1381.s
        expand=$work/$name.s
    fi
    if run_guest "$name" "$work/drop.s" "$work/full.s" "$rebase" "$expand" > "$work/$name.log" 2>&1; then
        echo "FAIL: $name accepted" >&2; exit 1
    fi
    grep -F 'FAIL: __test_exit' "$work/$name.log" || { cat "$work/$name.log"; exit 1; }
    echo "PASS: $name rejected"
done
