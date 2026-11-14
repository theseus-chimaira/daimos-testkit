#!/bin/sh
# v1555 PDP-6: central DTFS DATA/DIR write veneer denies published V2.
# No raw Type-551 write may be issued to a mounted V2 unit.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-write-v1555.XXXXXX")
if [ "${V1555_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo,work=(Path(s) for s in sys.argv[1:])
full=(repo/'system/kernel/fs/dtfs_runtime.s').read_text()
start=full.index('dtfs_dtc_write:\n')
end=full.index('        .globl  dtfs_dtc_write_jump\n',start)
source='.text\n.globl dtfs_dtc_write\n'+full[start:end]
assert source.count('dtfs_v2_ro_write_guard_v1555:')==1
assert source.count('pushj   17,dtfs_v2_ro_write_guard_v1555')==1
mutants=(
    ('bypass-v2-write-guard',
     'pushj   17,dtfs_v2_ro_write_guard_v1555',
     'setz    1,                     ; wrong: always permit DATA writes'),
    ('reverse-v2-write-refusal',
     'jumpn   1,dtfs_dtc_write_v2_refuse_v1555',
     'jumpe   1,dtfs_dtc_write_v2_refuse_v1555'),
    ('ignore-v2-format-tag',
     'trnn    7,0100000',
     'trne    7,0100000'),
    ('skip-provider-identity',
     'caie    7,5                     ; DTFS only',
     'caie    7,6                     ; wrong provider'),
    ('skip-physical-unit-match',
     'came    7,1',
     'camn    7,1'),
    ('allow-mount-in-later-slot',
     'sojg    6,dtfs_v2_guard_next_v1555',
     'jrst    dtfs_v2_write_allowed_v1555'),
    ('skip-published-root-check',
     'lsh     7,-036                 ; mounted vnode provider',
     'movei   7,5                    ; wrong: ignore root provider'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1555.s')).write_text(source.replace(old,new,1))
(work/'write-source-v1555.s').write_text(source)
print('v1555: 12 actual PDP-6 write-guard scenarios and %d mutants' % len(mutants))
PY

run_native() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 120000 --timeout 15 \
        --workdir "$work/run-$label" --name "dtfs-v2-write-$label-v1555" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-v2-ro-write-guard-v1555.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_native baseline "$work/write-source-v1555.s"; then
    tail -60 "$work/baseline.log" >&2
    echo 'FAIL v1555: central DTFS write gate' >&2
    exit 1
fi
echo 'PASS v1555: native write veneer refuses V2 before raw DTC transfer'

for mutation in bypass-v2-write-guard reverse-v2-write-refusal \
    ignore-v2-format-tag skip-provider-identity \
    skip-physical-unit-match allow-mount-in-later-slot \
    skip-published-root-check; do
    if run_native "$mutation" "$work/mutant-$mutation-v1555.s"; then
        echo "FAIL v1555: unsafe write mutation accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1555: write mutant failed outside native oracle: $mutation" >&2
        tail -30 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1555: rejected $mutation"
done
echo 'PASS v1555: production common DTC veneer fail-closed for V2'
