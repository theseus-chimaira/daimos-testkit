#!/bin/sh
# v1536: link exact KINIT C reservation and PDP-6 BACKSTORE allocator
# against strict bitmap and persistent-snapshot ownership assertions.
# All generated sources, binaries, logs and mutants stay in testkit.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-snapshot-swap-reserve-v1536.XXXXXX")
trap 'if [ "${V1536_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v1536 evidence: $work"; fi' EXIT HUP INT TERM

boot="$DAIMOS_REPO/system/kernel/proc/proc_swap_boot.c"
backing="$DAIMOS_REPO/system/kernel/storage/backstore.s"
native="$self/daimos-snapshot-swap-allocator-v1536.s"
host="$self/daimos-snapshot-swap-reserve-v1536-host.c"
incs="-I$DAIMOS_REPO/system/kernel/core"
incs="$incs -I$DAIMOS_REPO/system/kernel/proc"
incs="$incs -I$DAIMOS_REPO/system/kernel/fs"
incs="$incs -I$DAIMOS_REPO/system/kernel/storage"
incs="$incs -I$DAIMOS_REPO/system/kernel/mm"
incs="$incs -I$PDP10_PREFIX/include"

run_host()
{
    kind=$1
    source=$2
    ${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror $incs \
        -o "$work/host-$kind" "$host" "$source"
    "$work/host-$kind" > "$work/host-$kind.log" 2>&1
}

python3 - "$boot" "$backing" "$work" <<'PY'
from pathlib import Path
import sys

boot, backing, out = (Path(p) for p in sys.argv[1:])
src = boot.read_text()
mutations = (
    ('drop-v2-version',
     'h[1] != MEMFS_SNAPSHOT_VERSION_V1480',
     'h[1] == MEMFS_SNAPSHOT_VERSION_V1480'),
    ('skip-commit-last',
     'h[2] + h[3] != blocks',
     'h[2] + h[3] == blocks'),
    ('drop-cache-invalidation',
     '        bcache_workspace_invalidate();',
     '        /* intentionally unsafe: no invalidation */;'),
    ('erase-snapshot-bitmap',
     '                backstore_bitmap[word] |= mask;',
     '                backstore_bitmap[word] &= ~mask;'),
)
for name, before, after in mutations:
    assert src.count(before) == 1, (name, src.count(before))
    (out / ('mutant-' + name + '.c')).write_text(
        src.replace(before, after, 1))

raw = backing.read_text()
def section(start, end):
    assert raw.count(start) == 1, start
    i = raw.index(start)
    j = raw.index(end, i + len(start))
    return raw[i:j]

alloc = section('backstore_alloc:\n',
                '\n; int backstore_extend(first,old_blocks,new_blocks)')
verify = section('backstore_verify_allocated_v795:\n',
                 '\n; int backstore_extend(first,old_blocks,new_blocks)\n'
                 '; The existing run must be fully allocated')
release = section('backstore_free:\n', '\n        .bss\n')
assert 'backstore_alloc_mark:' in alloc
assert 'backstore_verify_loop_v795:' in verify
assert 'backstore_free_loop:' in release
assembled = ('.text\n.globl backstore_alloc\n'
    '.globl backstore_verify_allocated_v795\n.globl backstore_free\n'
    + alloc + '\n' + verify + '\n' + release + '\n')
(out / 'source-v1536.s').write_text(assembled)
negatives = (
    ('ignore-bitmap', '        tdne    3,(1)',
     '        tdnn    3,(1)'),
    ('lose-allocation-accounting',
     '        addm    010,backstore_blocks_used',
     '        move    010,010'),
    ('disable-owner-check', '        pushj   17,backstore_verify_allocated_v795',
     '        setz    1,'),
)
for name, before, after in negatives:
    assert assembled.count(before) == 1, (name, assembled.count(before))
    (out / ('mutant-' + name + '.s')).write_text(
        assembled.replace(before, after, 1))
PY

run_host baseline "$boot" || {
    tail -80 "$work/host-baseline.log" >&2
    echo 'FAIL v1536: source-linked boot reservation' >&2
    exit 1
}
tail -11 "$work/host-baseline.log"
for name in drop-v2-version skip-commit-last drop-cache-invalidation \
    erase-snapshot-bitmap; do
    if run_host "$name" "$work/mutant-$name.c"; then
        echo "FAIL v1536: unsafe KINIT $name survived" >&2
        exit 1
    fi
    grep -q '^FAIL v1536:' "$work/host-$name.log" || {
        tail -35 "$work/host-$name.log" >&2
        echo "FAIL v1536: KINIT $name did not reach assertion" >&2
        exit 1
    }
    echo "PASS v1536: rejected KINIT $name mutation"
done

run_native()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 1000000 \
        --timeout 40 --workdir "$work/run-$name" \
        --name "snapshot-swap-$name-v1536" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$source" "$native" > "$work/native-$name.log" 2>&1
}
if ! run_native baseline "$work/source-v1536.s"; then
    tail -75 "$work/native-baseline.log" >&2
    echo 'FAIL v1536: real PDP-6 BACKSTORE allocation with snapshot' >&2
    exit 1
fi
echo 'PASS v1536: actual PDP-6 BACKSTORE alloc/free excludes snapshot'
for name in ignore-bitmap lose-allocation-accounting disable-owner-check; do
    if run_native "$name" "$work/mutant-$name.s"; then
        echo "FAIL v1536: unsafe PDP-6 $name survived" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/native-$name.log" || {
        tail -45 "$work/native-$name.log" >&2
        echo "FAIL v1536: $name did not reach executed oracle" >&2
        exit 1
    }
    echo "PASS v1536: rejected PDP-6 $name mutation"
done
echo 'PASS v1536: KINIT snapshot reservation + native BACKSTORE owner matrix'
