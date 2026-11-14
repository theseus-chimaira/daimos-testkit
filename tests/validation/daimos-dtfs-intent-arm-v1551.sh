#!/bin/sh
# Real PDP-6 source-linked raw DTVOL2 write-ahead arming, no mounted KCORE.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-intent-arm-v1551.XXXXXX")
if [ "${V1551_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1551" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1551" --durable-v1550 -o "$work/clean-v1551.tap"
"$work/mkdtfs-v1551" -o "$work/legacy-v1551.tap"

python3 - "$work" "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys
work,repo=(Path(s) for s in sys.argv[1:])

def record(name):
    data=(work/name).read_bytes()[:0o200*8]
    assert len(data)==0o200*8
    values=[]
    for offset in range(0,len(data),8):
        upper=int.from_bytes(data[offset:offset+4],'little')
        lower=int.from_bytes(data[offset+4:offset+8],'little')
        assert upper<=0o777777 and lower<=0o777777
        values.append((upper<<18)|lower)
    return values

clean=record('clean-v1551.tap')
legacy=record('legacy-v1551.tap')
dirty=list(clean)
dirty[4]=0o552255225522
dirty[5]=(~(dirty[0]^dirty[1]^dirty[2]^dirty[4]^0o246134572610))&0o777777777777
assert clean[0]==0o446466575422 and legacy[0]==0o446466575421

lines=['.data\n']
for name, values in [('clean',clean),('dirty',dirty),('legacy',legacy)]:
    lines.extend(['.globl record_%s_v1551\n' % name,
                  'record_%s_v1551:\n' % name])
    for value in values:
        # Explicit octal prefix is essential for 36-bit PDP-6 data.
        lines.append('        .word 0%012o\n' % value)
(work/'real-media-v1551.s').write_text(''.join(lines))

arm=(repo/'system/kernel/fs/dtfs_intent_arm_v1551.s').read_text()
mutants=(
    ('skip-initial-scratch-clear',
     'pushj   17,dtfs_arm_clear_scratch_v1551',
     'move    2,2                   ; accept old CLEAN scratch'),
    ('skip-readback-scratch-clear',
     '; record in RAM must not be mistaken for verified on-media intent.\n'
     '        pushj   17,dtfs_arm_clear_scratch_v1551',
     '; record in RAM must not be mistaken for verified on-media intent.\n'
     '        move    2,2                   ; old DIRTY scratch'),
    ('skip-clean-admission',
     'jumpn   1,dtfs_arm_reject_v1551',
     'jumpe   1,dtfs_arm_reject_v1551'),
    ('skip-high-identity',
     'came    2,1(013)', 'came    2,2'),
    ('skip-low-identity',
     'came    2,2(013)', 'came    2,2'),
    ('skip-dirty-checksum',
     'caie    1,1                     ; exact WRITE_INTENT state',
     'caie    1,0                     ; exact WRITE_INTENT state'),
    ('skip-poison',
     'pushj   17,dtfs_mark_unit_suspect_v1522',
     'setz    1,                      ; lost poison ownership'),
    ('skip-cache-invalidate',
     'pushj   17,bcache_invalidate_all',
     'setz    1,                      ; stale BCACHE tags persist'),
    ('skip-physical-readback',
     'pushj   17,dtfs_dtc_read_jump\n        jumpn   1,dtfs_arm_uncertain_v1551',
     'setz    1,\n        jumpn   1,dtfs_arm_uncertain_v1551'),
    ('skip-write-error',
     'pushj   17,dtfs_dtc_write_jump\n        jumpn   1,dtfs_arm_uncertain_v1551',
     'pushj   17,dtfs_dtc_write_jump\n        jumpe   1,dtfs_arm_uncertain_v1551'),
)
for name,old,new in mutants:
    count=arm.count(old)
    expected=2 if name in ('skip-clean-admission','skip-high-identity',
                           'skip-low-identity','skip-initial-scratch-clear') else 1
    assert count==expected,(name,count,expected)
    # The same high/low checks recur after raw readback. Remove both
    # checks in their corresponding unsafe mutations.
    replacements=2 if name in ('skip-high-identity','skip-low-identity') else 1
    (work/('mutant-'+name+'-v1551.s')).write_text(
        arm.replace(old,new,replacements))
print('v1558: 17 real-media physical boundary cases and %d mutations' % len(mutants))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 400000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-arm-$label-v1551" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-intent-arm-v1551.s" \
        "$work/real-media-v1551.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_arm_v1551.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1551: native physical RBN0 arm service' >&2
    exit 1
fi
echo 'PASS v1558: 17 actual PDP-6 arm/rollback/readback cases'

for mutation in skip-initial-scratch-clear skip-readback-scratch-clear \
    skip-clean-admission skip-high-identity \
    skip-low-identity skip-dirty-checksum skip-poison \
    skip-cache-invalidate \
    skip-physical-readback skip-write-error; do
    if run_case "$mutation" "$work/mutant-$mutation-v1551.s"; then
        echo "FAIL v1551: unsafe source mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1551: mutant never reached native test oracle: $mutation" >&2
        tail -32 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1551: rejected $mutation"
done
echo 'PASS v1551: raw dirty-before-data arm service source acceptance'
