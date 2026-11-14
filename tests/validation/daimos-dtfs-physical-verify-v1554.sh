#!/bin/sh
# Physical DTVOL2/DIRTY readback for an already-armed DTFS mount on PDP-6.
# The full native raw-verify and record parser run; Type-551 I/O controlled.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-physical-verify-v1554.XXXXXX")
if [ "${V1554_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1554" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1554" --durable-v1550 -o "$work/v2-clean.tap"
"$work/mkdtfs-v1554" -o "$work/v1-old.tap"

python3 - "$work" "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys

work,repo=(Path(x) for x in sys.argv[1:])
mask=0o777777777777
dirty_state=0o552255225522
seal_salt=0o246134572610

def block(filename):
    data=(work/filename).read_bytes()[:128*8]
    assert len(data)==1024
    words=[]
    for i in range(0,len(data),8):
        high=int.from_bytes(data[i:i+4],'little')
        low=int.from_bytes(data[i+4:i+8],'little')
        assert high<=0o777777 and low<=0o777777
        words.append((high<<18)|low)
    return words

clean=block('v2-clean.tap')
old=block('v1-old.tap')
assert clean[0]==0o446466575422 and old[0]==0o446466575421
assert clean[1] and clean[2]

def repair_checks(record):
    result=record[:]
    result[3]=(~(result[0]^result[1]^result[2]))&mask
    result[5]=(~(result[0]^result[1]^result[2]^result[4]^seal_salt))&mask
    return result

dirty=clean[:]
dirty[4]=dirty_state
dirty=repair_checks(dirty)
other_hi=dirty[:]
other_hi[1]^=0o456712
other_hi=repair_checks(other_hi)
other_lo=dirty[:]
other_lo[2]^=0o527641
other_lo=repair_checks(other_lo)
assert other_hi[1]!=dirty[1] and other_lo[2]!=dirty[2]

records=(('dirty',dirty),('clean',clean),('old',old),
         ('other_hi',other_hi),('other_lo',other_lo))
lines=['.data\n']
for name,values in records:
    assert len(values)==128
    lines.append('.globl record_%s_v1554\n' % name)
    lines.append('record_%s_v1554:\n' % name)
    for word in values:
        lines.append('        .word 0%012o\n' % word)
(work/'media-records-v1554.s').write_text(''.join(lines))

source=(repo/'system/kernel/fs/dtfs_intent_verify_v1554.s').read_text()
mutants=(
    ('skip-physical-read',
     'pushj   17,dtfs_dtc_read_jump',
     'setz    1,                      ; counterfeit raw read success'),
    ('ignore-read-error',
     'jumpn   1,dtfs_verify_suspect_v1554',
     'jumpe   1,dtfs_verify_suspect_v1554'),
    ('skip-dirty-state',
     'caie    1,1                     ; exact WRITE_INTENT, NOT CLEAN',
     'caie    1,0                     ; wrongly admit clean media'),
    ('skip-high-identity',
     'came    2,1(013)',
     'came    2,2'),
    ('skip-low-identity',
     'came    2,2(013)',
     'came    2,2'),
    ('wrong-rbn',
     'setz    2,                      ; reserved physical RBN0',
     'movei   2,1                     ; wrong physical block'),
    ('wrong-dtc-unit',
     'move    1,010\n        setz    2,',
     'movei   1,1\n        setz    2,'),
    ('skip-scratch-clear',
     'setzm   (2)',
     'move    2,2                     ; stale scratch reused'),
    ('skip-poison',
     'pushj   17,dtfs_mark_unit_suspect_v1522',
     'setz    1,                      ; missing sticky poison'),
    ('skip-cache-eviction',
     'pushj   17,bcache_invalidate_all',
     'setz    1,                      ; stale BCACHE survives'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1554.s')).write_text(source.replace(old,new,1))
print('v1554: 17 genuine host-media native cases and %d mutations' % len(mutants))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 270000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-verify-$label-v1554" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-physical-verify-v1554.s" \
        "$work/media-records-v1554.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_verify_v1554.s"; then
    tail -70 "$work/baseline.log" >&2
    echo 'FAIL v1554: physical DIRTY identity readback' >&2
    exit 1
fi
echo 'PASS v1554: 17 native PDP-6 genuine DTVOL2 physical RBN0 cases'

for mutation in skip-physical-read ignore-read-error skip-dirty-state \
    skip-high-identity skip-low-identity wrong-rbn wrong-dtc-unit \
    skip-scratch-clear skip-poison skip-cache-eviction; do
    if run_case "$mutation" "$work/mutant-$mutation-v1554.s"; then
        echo "FAIL v1554: unsafe source mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1554: mutant did not reach native oracle: $mutation" >&2
        tail -30 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1554: rejected $mutation"
done
echo 'PASS v1554: physical on-media DIRTY identity gate accepted'
