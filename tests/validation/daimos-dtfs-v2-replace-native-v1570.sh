#!/bin/sh
# v1570: real source-linked PDP-6 replacement verifier, V1 and V2.
# Only daimos-testkit contains generated fixtures and unsafe mutants.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-replace-native-v1570.XXXXXX")
if [ "${V1570_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1570: retained native test $work"
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1570" "$DAIMOS_REPO/tools/host/mkdtfs.c"
for variant in v2a v2b; do
    "$work/mkdtfs-v1570" --durable-v1550 -o "$work/$variant.tap"
done
for variant in v1a v1b; do
    "$work/mkdtfs-v1570" -o "$work/$variant.tap"
done

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import struct
import sys

repo, work = (Path(s) for s in sys.argv[1:])
mask = 0o777777777777
salt = 0o246134572610
dirty = 0o552255225522


def record(name, rbn):
    with (work / (name + '.tap')).open('rb') as f:
        f.seek(rbn * 1024)
        data = f.read(1024)
    assert len(data) == 1024
    words = []
    for index in range(0, 1024, 8):
        hi, lo = struct.unpack_from('<II', data, index)
        assert hi <= 0o777777 and lo <= 0o777777
        words.append((hi << 18) | lo)
    return words


v2a = record('v2a', 0)
v2b = record('v2b', 0)
v1a = record('v1a', 0)
v1b = record('v1b', 0)
directory = record('v2b', 0o144)
assert v2a[0] == v2b[0] == 0o446466575422
assert v1a[0] == v1b[0] == 0o446466575421
assert v2a[1:3] != v2b[1:3] and v1a[1:3] != v1b[1:3]


def salted(x):
    x[5] = (~(x[0] ^ x[1] ^ x[2] ^ x[4] ^ salt)) & mask
    return x


def copy(x):
    return x[:]


dirty2 = copy(v2b)
dirty2[4] = dirty
salted(dirty2)
badseal = copy(v2b)
badseal[5] ^= 1
badpad = copy(v2b)
badpad[15] = 1
badid = copy(v2b)
badid[3] ^= 1
zeroid = copy(v2b)
zeroid[2] = 0
zeroid[3] = (~(zeroid[0] ^ zeroid[1])) & mask
salted(zeroid)
badstate = copy(v2b)
badstate[4] = 1
salted(badstate)
changedlow = copy(v2b)
changedlow[2] ^= 0o12345
changedlow[3] = (~(changedlow[0] ^ changedlow[1] ^ changedlow[2])) & mask
salted(changedlow)
changedhigh = copy(v2b)
changedhigh[1] ^= 0o54321
changedhigh[3] = (~(changedhigh[0] ^ changedhigh[1] ^ changedhigh[2])) & mask
salted(changedhigh)
sameid = copy(v2a)

records = {'v2a':v2a, 'v2b':v2b, 'v1a':v1a, 'v1b':v1b,
           'v2dirty':dirty2, 'v2badseal':badseal, 'v2badpad':badpad,
           'v2badid':badid, 'v2zeroid':zeroid, 'v2badstate':badstate,
           'v2low':changedlow, 'v2high':changedhigh,
           'v2same':sameid, 'dir':directory}

v2media = 0o500003        # native, physical DTC3, FORMAT_V2, WR_UNCERTAIN
v1media = 0o400003        # old V1 poisoned volume
cases = [
    ('different clean V2', 'v2b', 0, v2media, 'v2a', 0, 2, 1),
    ('same clean V2 refused', 'v2same', 0, v2media, 'v2a', -1, 2, 1),
    ('different DIRTY V2 refused', 'v2dirty', 0, v2media, 'v2a', -1, 2, 1),
    ('same DIRTY V2 refused', 'v2dirty', 0, v2media, 'v2dirty', -1, 2, 1),
    ('bad salted V2 seal', 'v2badseal', 0, v2media, 'v2a', -1, 2, 1),
    ('nonzero V2 padding', 'v2badpad', 0, v2media, 'v2a', -1, 2, 1),
    ('invalid V2 identity complement', 'v2badid', 0, v2media, 'v2a', -1, 2, 1),
    ('empty V2 identity low', 'v2zeroid', 0, v2media, 'v2a', -1, 2, 1),
    ('invalid V2 state', 'v2badstate', 0, v2media, 'v2a', -1, 2, 1),
    ('new V2 different low', 'v2low', 0, v2media, 'v2a', 0, 2, 1),
    ('new V2 different high', 'v2high', 0, v2media, 'v2a', 0, 2, 1),
    ('V2 to V1 downgrade refused', 'v1b', 0, v2media, 'v2a', -1, 2, 1),
    ('V1 to V2 upgrade refused', 'v2b', 0, v1media, 'v1a', -1, 2, 1),
    ('V1 to V1 still accepted', 'v1b', 0, v1media, 'v1a', 0, 2, 1),
    ('V1 same identity refused', 'v1a', 0, v1media, 'v1a', -1, 2, 1),
    ('V2 missing original high', 'v2b', 0o20, v2media, 'v2a', -1, 0, 0),
    ('V2 missing original low', 'v2b', 0o21, v2media, 'v2a', -1, 0, 0),
    ('V2 not write-uncertain', 'v2b', 0, 0o100003, 'v2a', -1, 0, 0),
    ('V2 directory empty transfer', 'v2b', 1, v2media, 'v2a', -1, 1, 1),
    ('V2 directory short transfer', 'v2b', 2, v2media, 'v2a', -1, 1, 1),
    ('V2 directory physical error', 'v2b', 3, v2media, 'v2a', -1, 1, 1),
    ('V2 invalid directory magic', 'v2b', 4, v2media, 'v2a', -1, 1, 1),
    ('V2 missing reserved RBN0 owner', 'v2b', 5, v2media, 'v2a', -1, 1, 1),
    ('V2 missing RBN0144 owner', 'v2b', 6, v2media, 'v2a', -1, 1, 1),
    ('V2 invalid directory tail', 'v2b', 7, v2media, 'v2a', -1, 1, 1),
    ('V2 RBN0 empty transfer', 'v2b', 0o10, v2media, 'v2a', -1, 2, 1),
    ('V2 RBN0 short transfer', 'v2b', 0o11, v2media, 'v2a', -1, 2, 1),
    ('V2 RBN0 physical error', 'v2b', 0o12, v2media, 'v2a', -1, 2, 1),
    ('V2 RBN0 torn identity', 'v2b', 0o13, v2media, 'v2a', -1, 2, 1),
    ('V2 RBN0 padded', 'v2b', 0o14, v2media, 'v2a', -1, 2, 1),
]


def word(value):
    return '-1' if value == -1 else '0%012o' % value


lines = ['.data\n']
for name, values in records.items():
    assert len(values) == 128
    lines.append('.globl record_%s_v1558\nrecord_%s_v1558:\n' % (name, name))
    lines.extend('        .word ' + word(value) + '\n' for value in values)
lines.append('.globl cases_v1558\n.globl case_count_v1558\n')
lines.append('.equ case_count_v1558,0%o\ncases_v1558:\n' % len(cases))
for desc,name,mode,status,original,ret,reads,flush in cases:
    lines.append('        ; '+desc+'\n')
    values=('record_%s_v1558' % name, word(mode), word(status),
            'record_%s_v1558' % original, word(ret), word(reads),
            word(flush))
    lines.extend('        .word ' + value + '\n' for value in values)
(work/'cases-v1570.s').write_text(''.join(lines))

runtime = (repo/'system/kernel/fs/dtfs_runtime.s').read_text()
start = runtime.index('dtfs_verify_replacement_v1531:\n')
replacement = runtime[start:runtime.index('        .data\ndtfs_mres_vector:',start)]
start = runtime.index('dtfs_workspace_clear_v1558:\n')
clear = runtime[start:runtime.index('; Shared LEGACY native identity parser',start)]
start = runtime.index('dtfs_identity_validate_v1522:\n')
validator = runtime[start:runtime.index('dtfs_lookup:\n',start)]
parser = (repo/'system/kernel/fs/dtfs_intent_validate_v1550.s').read_text()
source = ('.text\n.globl dtfs_verify_replacement_v1531\n' +
          replacement + clear + validator + parser)
assert 'dtfs_replace_identity_v1570:' in source

mutants = [
    ('bypass-V2-seal', 'pushj   17,dtfs_intent_validate_v1550',
     'setz    1,                      ; corrupt/dirty accepted'),
    ('skip-V2-clean',
     'jumpn   1,dtfs_replace_bad_v1531 ; DIRTY and corrupt forbidden',
     'jrst    dtfs_replace_identity_v1570'),
    ('skip-V2-original-format',
     'trnn    4,0100000              ; old mount must also be V2',
     'trnn    4,0'),
    ('skip-V1-downgrade',
     'trne    4,0100000              ; no V2 -> V1 downgrade',
     'trne    4,0'),
    ('accept-same-identity',
     'camn    4,fs_block_workspace+2 ; both halves equal: old medium',
     'came    4,fs_block_workspace+2 ; wrong same ID'),
    ('omit-directory-validation', 'came    1,[0446446632021]',
     'came    1,1'),
    ('omit-directory-clear', 'pushj   17,dtfs_workspace_clear_v1558',
     'move    4,4                    ; stale native directory'),
    ('skip-physical-RBN0', 'pushj   17,dtfs_dtc_read_jump',
     'setz    1,                       ; skipped raw IO', -1),
]
for item in mutants:
    label,old,new = item[:3]
    assert source.count(old) >= 1,(label,source.count(old))
    if len(item) == 4:
        head,tail = source.rsplit(old,1)
        rewritten = head+new+tail
    else:
        rewritten = source.replace(old,new,1)
    (work/('mutant-'+label+'-v1570.s')).write_text(rewritten)
(work/'source-v1570.s').write_text(source)
print('v1570: %d source-linked physical-media V1/V2 cases, %d mutants' %
      (len(cases),len(mutants)))
PY

run_case()
{
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 900000 --timeout 30 \
        --workdir "$work/run-$label" --name "dtfs-replace-$label-v1570" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-replace-raw-preflight-v1558.s" \
        "$work/cases-v1570.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/source-v1570.s"; then
    tail -70 "$work/baseline.log" >&2
    echo 'FAIL v1570: V2 physical replacement preflight' >&2
    exit 1
fi
echo 'PASS v1570: 30 native V2/V1 raw replacement scenarios'
for mutant in bypass-V2-seal skip-V2-clean skip-V2-original-format \
    skip-V1-downgrade accept-same-identity omit-directory-validation \
    omit-directory-clear skip-physical-RBN0; do
    if run_case "$mutant" "$work/mutant-$mutant-v1570.s"; then
        echo "FAIL v1570: accepted unsafe $mutant" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -55 "$work/$mutant.log" >&2
        echo "FAIL v1570: mutant $mutant failed outside oracle" >&2
        exit 1
    }
    echo "PASS v1570: rejected $mutant"
done
echo 'PASS v1570: native V2 replacement and unsafe mutations'
