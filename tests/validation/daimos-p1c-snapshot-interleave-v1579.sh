#!/bin/sh
# Source-linked actual PDP-6 snapshot mount/shutdown and BACKSTORE allocator.
# Synthetic block I/O only: this is a native transaction test, not a guest
# that proves simultaneous process swap I/O or a natural controller failure.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-snapshot-interleave-v1579.XXXXXX")
if [ "${V1579_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1579 evidence: $work"
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, output = Path(sys.argv[1]), Path(sys.argv[2])
snapshot = (repo / 'system/kernel/fs/memfs_snapshot_pdp6.s').read_text()
allocator = (repo / 'system/kernel/storage/backstore.s').read_text()
anchor = '; Zero means volatile/disabled; otherwise first-block,,reserved-block-count.\n'
assert snapshot.count(anchor) == 1, 'snapshot source layout changed'
snapshot = snapshot.replace(anchor, '        .globl snapshot_span\n' + anchor, 1)
(output / 'snapshot-source-v1579.s').write_text(snapshot)
(output / 'backstore-source-v1579.s').write_text(allocator)

mutations = (
    ('snapshot-bitmap-lost', 'snapshot', '        iorm    3,(1)',
     '        andm    3,(1)'),
    ('snapshot-commit-lost', 'snapshot',
     '        movem   1,fs_block_workspace+5\n'
     '        move    1,backstore_blocks',
     '        movem   1,fs_block_workspace+5\n'
     '        jrst    memfs_snapshot_shutdown_ok\n'
     '        move    1,backstore_blocks'),
    ('allocator-owner-lost', 'backstore',
     '        tdne    3,(1)                  ; clear bit skips occupied branch',
     '        tdnn    3,(1)                  ; unsafe: treat occupied as free'),
)
for name, which, old, new in mutations:
    source = snapshot if which == 'snapshot' else allocator
    assert source.count(old) == 1, (name, source.count(old))
    (output / ('mutant-' + name + '.s')).write_text(
        source.replace(old, new, 1))
print('v1579: extracted exact production snapshot and allocator source')
PY

run_native()
{
    name=$1
    snap=$2
    alloc=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 5000000 \
        --timeout 60 --workdir "$work/run-$name" \
        --name "p1c-snapshot-$name-v1579" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$snap" "$alloc" \
        "$self/daimos-p1c-snapshot-interleave-v1579.s" \
        > "$work/native-$name.log" 2>&1
}

if ! run_native baseline "$work/snapshot-source-v1579.s" \
        "$work/backstore-source-v1579.s"; then
    tail -90 "$work/native-baseline.log" >&2
    echo 'FAIL v1579: native original-source interleaved transaction' >&2
    exit 1
fi
echo 'PASS v1579: real PDP-6 snapshot/allocator interleaved ownership and commit'

for name in snapshot-bitmap-lost snapshot-commit-lost allocator-owner-lost; do
    snap="$work/snapshot-source-v1579.s"
    alloc="$work/backstore-source-v1579.s"
    case "$name" in
        snapshot-*) snap="$work/mutant-$name.s" ;;
        allocator-*) alloc="$work/mutant-$name.s" ;;
    esac
    if run_native "$name" "$snap" "$alloc"; then
        echo "FAIL v1579: unsafe $name mutation survived" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/native-$name.log" || {
        tail -60 "$work/native-$name.log" >&2
        echo "FAIL v1579: $name failed for a non-oracle reason" >&2
        exit 1
    }
    echo "PASS v1579: rejected executed $name mutation"
done
echo 'PASS v1579: scoped native P1-C test; physical concurrent HALT/swap OPEN'
