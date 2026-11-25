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
work=$(mktemp -d "$TMPDIR/pure-mm-geometry-v1921.XXXXXX")
trap 'echo "v1921 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
compile -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 "$src/proc/proc_pure_restore_v1384.c" -o "$work/prefix.s"
full_compile() {
    compile -DDAIMOS_PURE_FULL_V1391=1 -Dmm_pin=pin_v1921 -Dmm_unpin=unpin_v1921 -Dmm_free=free_v1921 "$1" -o "$2"
}
full_compile "$src/proc/proc_pure_ram_restore_v1391.c" "$work/full.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$kit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main retired_v1921_main\n'
    cat "$kit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
    printf '#undef main\n'
    cat "$here/test-native-v1921.c"
} > "$work/test.c"
compile "$work/test.c" -o "$work/test.s" > "$work/compile-test.log" 2>&1 || { cat "$work/compile-test.log"; exit 1; }
run_guest() {
    name=$1
    drop=$2
    full=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$drop" "$work/prefix.s" "$full" "$src/mm/mm_pure_rebase_v1381.s" "$src/mm/mm_pure_expand_v1384.s" "$src/proc/proc_storage_runtime_v30.s" "$src/drivers/device_state.s" "$work/test.s"
}
run_guest pure-mm-geometry-v1921 "$work/drop.s" "$work/full.s"
echo 'PASS v1921 six FULL reply faults and five geometry cases'
# Independently bypass each new ownership check in disposable sources.
python3 - "$src/proc" "$work" <<'PY'
from pathlib import Path
import sys
src, work=map(Path,sys.argv[1:])
f=(src/'proc_pure_ram_restore_v1391.c').read_text()
d=(src/'proc_pure_ram_v1381.c').read_text()
checks={
    'unsafe-source-pin': ('        if (proc_pure_full_owners_v1917(slot, source, raw, 0UL, words,\n            1U, 0U) != 1)\n                goto uncertain;\n        target = 0UL;', '        target = 0UL;'),
    'unsafe-target-pin': ('        target_pinned = 1;\n        if (proc_pure_full_owners_v1917(slot, source, raw, target, words,\n            1U, 1U) != 3)\n                goto uncertain;', '        target_pinned = 1;'),
    'unsafe-source-unpin': ('        target_pinned = 0;\n        if (proc_pure_full_owners_v1917(slot, source, raw, target, words,\n            1U, 0U) != 3)\n                goto uncertain;','        target_pinned = 0;'),
    'unsafe-rollback-free': ('        if (proc_pure_full_owners_v1917(slot, source, raw, target, words,\n            source_uncertain ? 2U : (unsigned int)source_pinned, 0U) != 3)\n                goto uncertain;',''),
    'unsafe-free-success': ('        switch (pram_source_free_reply_v1839(slot, source, raw, target, words)) {', '        if (rc != MM_OK) switch (pram_source_free_reply_v1839(slot, source, raw, target, words)) {'),
    'unsafe-full-order': ('mm_pure_table_v1922() != MM_OK ||', ''),
}
for name,(old,new) in checks.items():
    assert f.count(old)==1,name
    (work/(name+'.c')).write_text(f.replace(old,new,1))
old='mm_pure_table_v1922() != MM_OK'
assert d.count(old)==1
(work/'unsafe-sole-order.c').write_text(d.replace(old,'0',1))
PY
for name in unsafe-source-pin unsafe-target-pin unsafe-source-unpin unsafe-rollback-free unsafe-free-success unsafe-full-order unsafe-sole-order; do
    drop=$work/drop.s
    full=$work/full.s
    if [ "$name" = unsafe-sole-order ]; then
        compile -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 "$work/$name.c" -o "$work/$name.s"
        drop=$work/$name.s
    else
        full_compile "$work/$name.c" "$work/$name.s"
        full=$work/$name.s
    fi
    if run_guest "$name" "$drop" "$full" > "$work/$name.log" 2>&1; then
        echo "FAIL: $name accepted" >&2; exit 1
    fi
    grep -F 'FAIL: __test_exit' "$work/$name.log" || { cat "$work/$name.log"; exit 1; }
    echo "PASS: $name rejected"
done
