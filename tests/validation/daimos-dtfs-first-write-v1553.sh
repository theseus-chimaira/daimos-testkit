#!/bin/sh
# Authenticated per-mount v1553 gate on actual PDP-6, with unsafe mutants.
# Physical Type-551/MM boundary is the independently tested v1552 service.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-first-write-v1553.XXXXXX")
if [ "${V1553_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo,work=(Path(x) for x in sys.argv[1:])
source=(repo/'system/kernel/fs/dtfs_intent_first_write_v1553.s').read_text()
header=(repo/'system/kernel/fs/dtfs_media.h').read_text()
for name,cvalue,svalue in (
    ('DTFS_MEDIA_FORMAT_V2_V1553','0100000U',
     '.equ DTFS_V2_FORMAT_FLAG_V1553,0100000'),
    ('DTFS_MEDIA_INTENT_ARMED_V1553','0040000U',
     '.equ DTFS_V2_ARMED_FLAG_V1553,0040000')):
    assert ('#define '+name+' '+cvalue) in header,name
    assert svalue in source,name
mutants=(
    ('skip-v2-format',
     'trnn    013,DTFS_V2_FORMAT_FLAG_V1553',
     'trne    013,DTFS_V2_FORMAT_FLAG_V1553'),
    ('ignore-suspect-media',
     'trne    013,DTFS_V2_IO_SUSPECT_FLAGS_V1553',
     'trnn    013,DTFS_V2_IO_SUSPECT_FLAGS_V1553'),
    ('wrong-provider',
     'caie    4,5                     ; DTFS provider, not TSFS/D6FS',
     'caie    4,6                     ; incorrect provider acceptance'),
    ('wrong-mount-identity',
     'came    4,5                     ; exact mounted VFS slot',
     'camn    4,5                     ; wrong mount identity polarity'),
    ('skip-live-mount',
     'skipn   3,(1)',
     'skipe   3,(1)'),
    ('zero-high-ID-allowed',
     'jumpe   015,dtfs_first_refuse_v1553',
     'jumpn   015,dtfs_first_refuse_v1553'),
    ('zero-low-ID-allowed',
     'jumpe   016,dtfs_first_refuse_v1553',
     'jumpn   016,dtfs_first_refuse_v1553'),
    ('skip-retained-MM-handle',
     'skipn   (011)',
     'skipe   (011)'),
    ('bypass-physical-arm',
     'pushj   17,dtfs_intent_owned_arm_v1552',
     'setz    1,                      ; bypass durable physical marker'),
    ('ignore-arm-failure',
     'pushj   17,dtfs_intent_owned_arm_v1552\n'
     '        jumpn   1,dtfs_first_refuse_v1553',
     'pushj   17,dtfs_intent_owned_arm_v1552\n'
     '        jumpe   1,dtfs_first_refuse_v1553'),
    ('ignore-change-during-arming',
     'came    1,013',
     'camn    1,013'),
    ('skip-armed-bit-publish',
     'iorm    1,(012)',
     'setz    1,                       ; lost mounted-armed state'),
    ('wrong-physical-DTC-unit',
     'andi    014,7',
     'andi    014,1'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1553.s')).write_text(source.replace(old,new,1))
print('v1553: 18 native authenticated mount cases, %d unsafe mutants' % len(mutants))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 270000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-first-$label-v1553" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-first-write-v1553.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_first_write_v1553.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1553: authentic source-linked per-mount first-write gate' >&2
    exit 1
fi
echo 'PASS v1553: 18 native PDP-6 mount-state/first-write scenarios'

for mutation in skip-v2-format ignore-suspect-media wrong-provider \
    wrong-mount-identity skip-live-mount zero-high-ID-allowed \
    zero-low-ID-allowed skip-retained-MM-handle bypass-physical-arm \
    ignore-arm-failure ignore-change-during-arming \
    skip-armed-bit-publish wrong-physical-DTC-unit; do
    if run_case "$mutation" "$work/mutant-$mutation-v1553.s"; then
        echo "FAIL v1553: accepted unsafe source mutation $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1553: mutant did not reach native oracle: $mutation" >&2
        tail -35 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1553: rejected $mutation"
done
echo 'PASS v1553: first-write mount gate accepted in isolation'
