#!/bin/sh
# Native PDP-6 source-linked MM scratch lifetime for v1551 RBN0 arming.
# Real MM allocation/pin APIs are strictly modelled at their ABI boundary.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-owned-scratch-v1552.XXXXXX")
if [ "${V1552_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo,work=(Path(v) for v in sys.argv[1:])
source=(repo/'system/kernel/fs/dtfs_intent_owned_arm_v1552.s').read_text()

mutants=(
    ('no-physical-pin',
     'pushj   17,mm_pin',
     'setz    1,                      ; incorrectly pretend pinned'),
    ('no-physical-unpin',
     'pushj   17,mm_unpin',
     'setz    1,                      ; incorrectly pretend unpinned'),
    ('no-free',
     'pushj   17,mm_free',
     'setz    1,                      ; incorrectly pretend freed'),
    ('wrong-mm-owner',
     '.equ    DTFS_INTENT_SCRATCH_OWNER_V1552,015',
     '.equ    DTFS_INTENT_SCRATCH_OWNER_V1552,014'),
    ('wrong-mm-words',
     '.equ    DTFS_INTENT_SCRATCH_WORDS_V1552,0200',
     '.equ    DTFS_INTENT_SCRATCH_WORDS_V1552,0177'),
    ('skip-real-physical-arm',
     'pushj   17,dtfs_intent_arm_v1551',
     'setz    1,                      ; bypassing durable intent'),
    ('misreport-arming-failure',
     'pop     17,1                    ; original v1551 arm status',
     'pop     17,1\n        setz    1, ; wrong arm result'),
    ('lose-cleanup-failure-owner',
     'dtfs_owned_arm_release_fail_v1552:\n',
     'dtfs_owned_arm_release_fail_v1552:\n'
     '        setzm   (013) ; silently forget still-owned MM extent\n'),
    ('skip-existing-owner-check',
     'skipn   (013)                   ; prevent overwriting a leaked owner',
     'skipe   (013)                   ; unsafe existing-owner check'),
    ('free-without-verifying-unpin',
     'pushj   17,mm_unpin\n        jumpn   1,dtfs_owned_arm_release_fail_v1552',
     'pushj   17,mm_unpin\n        jumpe   1,dtfs_owned_arm_release_fail_v1552'),
)
for name,old,new in mutants:
    count=source.count(old)
    assert count in (1,2),(name,count)
    (work/('mutant-'+name+'-v1552.s')).write_text(source.replace(old,new,1))
print('v1552: 11 native MM lease cases and %d source mutants' % len(mutants))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 --timeout 15 \
        --workdir "$work/run-$label" --name "dtfs-owned-$label-v1552" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-owned-scratch-v1552.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_owned_arm_v1552.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1552: real PDP-6 MM lease wrapper baseline' >&2
    exit 1
fi
echo 'PASS v1552: 11 native PDP-6 MM scratch-owner scenarios'

for mutation in no-physical-pin no-physical-unpin no-free \
    wrong-mm-owner wrong-mm-words skip-real-physical-arm \
    misreport-arming-failure lose-cleanup-failure-owner \
    skip-existing-owner-check free-without-verifying-unpin; do
    if run_case "$mutation" "$work/mutant-$mutation-v1552.s"; then
        echo "FAIL v1552: unsafe mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1552: mutant failure was not from the native oracle: $mutation" >&2
        tail -34 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1552: rejected $mutation"
done
echo 'PASS v1552: optional pinned MM-owned intent scratch lifecycle'
