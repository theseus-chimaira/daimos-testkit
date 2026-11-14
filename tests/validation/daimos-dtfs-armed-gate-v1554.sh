#!/bin/sh
# v1554: every already-armed mount must physically verify DTVOL2/DIRTY.
# Actual PDP-6 source-linked gate, strict lower-service completion oracle.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-armed-gate-v1554.XXXXXX")
if [ "${V1554_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo,work=(Path(s) for s in sys.argv[1:])
source=(repo/'system/kernel/fs/dtfs_intent_first_write_v1553.s').read_text()
assert source.count('pushj   17,dtfs_intent_owned_verify_v1554')==1
assert source.count('pushj   17,dtfs_first_post_io_check_v1554')==2
mutants=(
    ('bypass-already-armed-physical-check',
     'pushj   17,dtfs_intent_owned_verify_v1554',
     'setz    1,                      ; false physical verification'),
    ('ignore-physical-readback-failure',
     'pushj   17,dtfs_intent_owned_verify_v1554\n'
     '        jumpn   1,dtfs_first_refuse_v1553',
     'pushj   17,dtfs_intent_owned_verify_v1554\n'
     '        jumpe   1,dtfs_first_refuse_v1553'),
    ('skip-post-readback-owner-check',
     'pushj   17,dtfs_first_post_io_check_v1554\n'
     '        jumpn   1,dtfs_first_refuse_v1553\n'
     '        jrst    dtfs_first_allowed_v1553',
     'setz    1, ; post-readback owner and media check lost\n'
     '        jumpn   1,dtfs_first_refuse_v1553\n'
     '        jrst    dtfs_first_allowed_v1553'),
    ('skip-post-readback-high-ID',
     'came    2,015',
     'came    2,2'),
    ('skip-post-readback-low-ID',
     'came    2,016',
     'came    2,2'),
    ('skip-post-readback-media-word',
     'came    1,013',
     'came    1,1'),
    ('skip-post-readback-retained-scratch',
     'dtfs_first_post_io_check_v1554:\n',
     'dtfs_first_post_io_check_v1554:\n'
     '        setzm   (011) ; incorrectly abandon unfreed MM owner\n'),
    ('skip-post-readback-lower-ID-pointer',
     'move    1,tsfs_extent_media_base\n'
     '        jumpe   1,dtfs_first_post_refuse_v1554',
     'move    1,tsfs_file_shape_base\n'
     '        jumpe   1,dtfs_first_post_refuse_v1554'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1554.s')).write_text(source.replace(old,new,1))
print('v1554: 23 actual PDP-6 gate cases; %d source mutations' % len(mutants))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 320000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-gate-$label-v1554" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-armed-gate-v1554.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_first_write_v1553.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1554: native already-armed gate' >&2
    exit 1
fi
echo 'PASS v1554: 23 native mounted-first-write and recheck cases'

for mutation in bypass-already-armed-physical-check \
    ignore-physical-readback-failure skip-post-readback-owner-check \
    skip-post-readback-high-ID skip-post-readback-low-ID \
    skip-post-readback-media-word skip-post-readback-retained-scratch \
    skip-post-readback-lower-ID-pointer; do
    if run_case "$mutation" "$work/mutant-$mutation-v1554.s"; then
        echo "FAIL v1554: unsafe source mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1554: mutant never reached native oracle: $mutation" >&2
        tail -35 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1554: rejected $mutation"
done
echo 'PASS v1554: mounted revalidation and post-IO owner checks'
