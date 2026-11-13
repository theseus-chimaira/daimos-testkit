#!/bin/sh
# Execute actual DTFS/BCACHE PDP-6 failure and mounted-ID transitions.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-mounted-id-v1522.XXXXXX")
if [ "${V1522_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(x) for x in sys.argv[1:])
text = (repo / 'system/kernel/fs/dtfs_runtime.s').read_text()
cache = (repo / 'system/kernel/storage/bcache_pdp6.s').read_text()
# The real BCACHE keeps its internal tags local to this assembly unit.
# Export only those two BSS labels in this *source-linked test image*.
# Otherwise fixture declarations silently create distinct test variables
# and never exercise the actual BCACHE slot-0 tag used by dtfs_dtc_read.
assert cache.count('bcache_state:    .block 1') == 1
cache = cache.replace('bcache_state:    .block 1',
    '        .globl bcache_state\n'
    '        .globl bcache_workspace_tag\n'
    'bcache_state:    .block 1', 1)

def section(a, b):
    assert text.count(a) == 1, a
    start = text.index(a)
    assert b in text[start:], b
    return text[start:text.index(b, start)]

bridge = section('dtfs_dtc_read:\n', '        .if DTFS_ENABLE_FOREIGN\n')
bridge = bridge.replace('dtfs_dtc_read_jump:\n        jrst    0',
                        'dtfs_dtc_read_jump:\n        jrst    test_raw_read_v1522')
bridge = bridge.replace('dtfs_dtc_write_jump:\n        jrst    0',
                        'dtfs_dtc_write_jump:\n        jrst    test_raw_write_v1522')
assert 'dtfs_mark_unit_suspect_v1522:' in bridge
parser = section('dtfs_identity_validate_v1522:\n', 'dtfs_lookup:\n')
sync = section('dtfs_sync:\n', '; Shared clean DTC block-cache veneers.')
space = section('dtfs_space:\n', '        .data\ndtfs_mres_vector:')
native = text.index('.else\n; Native-only build:')
load = text[native:]
load = load[load.index('dtfs_load:\n'):]
load = load[:load.index('\n.endif\n')]
guard = section('dtfs_identity_revalidate_v1522:\n',
                '\n\n.if DTFS_ENABLE_FOREIGN\n; Compact directory enumeration.')
source = ('.text\n.globl dtfs_dtc_read\n.globl dtfs_dtc_write\n'
          '.globl dtfs_load\n.globl dtfs_sync\n.globl dtfs_space\n'
          + bridge + parser + sync + space + load + '\n' + guard
          + '\n' + cache)
(out / 'source-v1522.s').write_text(source)

# Native oracle must reject source-level violations, not just compare text.
mutations = (
    ('skip-read-marker',
     'movei   2,0200000              ; READ_SUSPECT in media RH',
     'setz    2,                     ; READ_SUSPECT in media RH'),
    ('skip-write-marker',
     'movei   2,0400000              ; WRITE_UNCERTAIN in media RH',
     'setz    2,                     ; WRITE_UNCERTAIN in media RH'),
    ('accept-replaced-high',
     'came    4,fs_block_workspace+1',
     'came    4,4'),
    ('accept-replaced-low',
     'came    4,fs_block_workspace+2',
     'came    4,4'),
    ('accept-legacy',
     'move    4,(4)\n        jumpe   4,dtfs_identity_revalidate_fail_v1522\n        came    4,fs_block_workspace+1',
     'move    4,(4)\n        jumpe   4,kret_zero\n        came    4,fs_block_workspace+1'),
    ('unsafe-write-retry',
     'trne    5,0400000              ; WRITE_UNCERTAIN',
     'trne    5,0                    ; WRITE_UNCERTAIN'),
    ('lose-raw-slot',
     '        pop     17,6\n        move    4,tsfs_file_shape_base',
     '        pop     17,5\n        move    4,tsfs_file_shape_base'),
    ('stale-workspace-tag-v1527',
     '        pushj   17,bcache_workspace_invalidate',
     '        move    4,4'),
)
for name, old, new in mutations:
    assert source.count(old) == 1, (name, source.count(old))
    (out / ('mutant-' + name + '-v1522.s')).write_text(
        source.replace(old, new, 1))
PY

run_native() {
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 450000 \
        --timeout 30 --workdir "$work/run-$name" \
        --name "dtfs-mounted-$name-v1522" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-mounted-id-v1522.s" \
        "$source" > "$work/$name.log" 2>&1
}

if ! run_native baseline "$work/source-v1522.s"; then
    tail -75 "$work/baseline.log" >&2
    echo "FAIL v1522: original DTFS mounted-identity recovery" >&2
    exit 1
fi
echo 'PASS v1522: native physical read fault -> identity match/reject and dirty fail-closed'
for name in skip-read-marker skip-write-marker accept-replaced-high \
    accept-replaced-low accept-legacy unsafe-write-retry lose-raw-slot \
    stale-workspace-tag-v1527; do
    if run_native "$name" "$work/mutant-$name-v1522.s"; then
        echo "FAIL v1522: unsafe $name mutation survived" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/$name.log" || {
        tail -40 "$work/$name.log" >&2
        echo "FAIL v1522: $name did not reach native oracle" >&2
        exit 1
    }
    echo "PASS v1522: rejected native $name mutation"
done
