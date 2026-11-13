#!/bin/sh
# Exercise real PDP-6 DTVOL2 validator with physically generated host images.
# No change to KCORE mount/write admission is implied by this test.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-intent-v1550.XXXXXX")
if [ "${V1550_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1550" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1550" -o "$work/legacy-v1550.tap"
"$work/mkdtfs-v1550" --durable-v1550 -o "$work/clean-v1550.tap"

python3 - "$work" "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys

work,repo=(Path(x) for x in sys.argv[1:])
mask=0o777777777777
dirty=0o552255225522
salt=0o246134572610

def from_media(name):
    data=(work/name).read_bytes()[:128*8]
    assert len(data)==1024
    words=[]
    for pos in range(0,1024,8):
        high=int.from_bytes(data[pos:pos+4],'little')
        low=int.from_bytes(data[pos+4:pos+8],'little')
        assert high<=0o777777 and low<=0o777777
        words.append((high<<18)|low)
    return words

original=from_media('clean-v1550.tap')
legacy=from_media('legacy-v1550.tap')
assert original[0]==0o446466575422
assert legacy[0]==0o446466575421
assert original[5]==(~(original[0]^original[1]^original[2]^salt))&mask
assert original[6:]==[0]*122
assert legacy[4:]==[0]*124

def make_dirty(words):
    result=words[:]
    result[4]=dirty
    result[5]=(~(result[0]^result[1]^result[2]^dirty^salt))&mask
    return result

dirty_record=make_dirty(original)
bad_state=original[:]
bad_state[4]=1
bad_state[5]=(~(bad_state[0]^bad_state[1]^bad_state[2]^1^salt))&mask
bad_padding=original[:]
bad_padding[33]=1
bad_seal=original[:]
bad_seal[5]^=1
bad_id=original[:]
bad_id[3]^=1
zero_high=original[:]
zero_high[1]=0
zero_high[3]=(~(zero_high[0]^zero_high[1]^zero_high[2]))&mask
zero_high[5]=(~(zero_high[0]^zero_high[1]^zero_high[2]^salt))&mask
zero_low=original[:]
zero_low[2]=0
zero_low[3]=(~(zero_low[0]^zero_low[1]^zero_low[2]))&mask
zero_low[5]=(~(zero_low[0]^zero_low[1]^zero_low[2]^salt))&mask
bad_magic=original[:]
bad_magic[0]=0o446466575423
bad_magic[3]=(~(bad_magic[0]^bad_magic[1]^bad_magic[2]))&mask
bad_magic[5]=(~(bad_magic[0]^bad_magic[1]^bad_magic[2]^salt))&mask
partial_dirty=original[:]
partial_dirty[4]=dirty
replaced=original[:]
replaced[1]=(original[1]^0o777777777)&mask
replaced[3]=(~(replaced[0]^replaced[1]^replaced[2]))&mask
replaced[5]=(~(replaced[0]^replaced[1]^replaced[2]^salt))&mask
assert replaced[1] != original[1]

cases=(
    ('clean',original,0),
    ('dirty',dirty_record,1),
    ('old-v1',legacy,-1),
    ('old-zero',[0]*128,-1),
    ('bad-state',bad_state,-1),
    ('bad-padding',bad_padding,-1),
    ('bad-seal',bad_seal,-1),
    ('bad-identity-check',bad_id,-1),
    ('zero-high',zero_high,-1),
    ('zero-low',zero_low,-1),
    ('wrong-magic',bad_magic,-1),
    ('torn-first-state',partial_dirty,-1),
    ('different-valid-ID',replaced,0),
)
lines=[
    '; v1550 actual host mkdtfs media records, tested by PDP-6 CPU\n',
    '.text\n',
    '.globl main\n',
    '.globl __test_exit\n',
    '.globl dtfs_intent_validate_v1550\n',
    'main:\n',
    '        movei  010,case_table_v1550\n',
    '        movei  011,%d\n' % len(cases),
    'check_case_v1550:\n',
    '        move   1,(010)\n',
    '        pushj  17,dtfs_intent_validate_v1550\n',
    '        came   1,1(010)\n',
    '        jrst   case_fail_v1550\n',
    '        addi   010,2\n',
    '        sojg   011,check_case_v1550\n',
    '        setz   1,\n',
    '        popj   17,\n',
    'case_fail_v1550:\n',
    '        movei  1,1\n',
    '        popj   17,\n',
    '.data\n',
    'case_table_v1550:\n',
]
for name,values,result in cases:
    assert len(values)==128
    lines.append('        .word record_%s_v1550\n' % name.replace('-','_'))
    lines.append('        .word %d\n' % result)
for name,values,result in cases:
    lines.append('record_%s_v1550:\n' % name.replace('-','_'))
    for word in values:
        # PDP-10 assembler treats bare large constants as decimal. A
        # leading zero is required to deposit the exact octal 36-bit word.
        lines.append('        .word 0%012o\n' % word)
lines.append('.bss\n__test_exit: .block 1\n')
(work/'native-cases-v1550.s').write_text(''.join(lines))

source=(repo/'system/kernel/fs/dtfs_intent_validate_v1550.s').read_text()
mutants=(
    ('bypass-magic','came    2,[0446466575422]', 'came    2,2'),
    ('bypass-ID-check','came    2,3(1)', 'came    2,2'),
    ('bypass-state','came    5,[0552255225522]', 'came    5,5'),
    ('bypass-seal','came    2,5(1)', 'came    2,2'),
    ('bypass-padding','skipn   (2)', 'skipn   [0]'),
    ('ignore-high-ID-zero','jumpe   3,dtfs_intent_bad_v1550',
     'jumpe   3,dtfs_intent_seal_v1550'),
    ('ignore-low-ID-zero','jumpe   4,dtfs_intent_bad_v1550',
     'jumpe   4,dtfs_intent_seal_v1550'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1550.s')).write_text(source.replace(old,new,1))
print('v1550: %d media-driven native cases, %d source mutants' %
      (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-intent-$label-v1550" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$work/native-cases-v1550.s" "$source" \
        > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s"; then
    tail -75 "$work/baseline.log" >&2
    echo 'FAIL v1550: actual PDP-6 DTVOL2 parser' >&2
    exit 1
fi
echo 'PASS v1550: native PDP-6 parsed 13 host-media and corrupted records'

for mutation in bypass-magic bypass-ID-check bypass-state \
    bypass-seal bypass-padding ignore-high-ID-zero ignore-low-ID-zero; do
    if run_case "$mutation" "$work/mutant-$mutation-v1550.s"; then
        echo "FAIL v1550: unsafe mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1550: mutant failure was not a native oracle: $mutation" >&2
        tail -34 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1550: rejected source mutation $mutation"
done
echo 'PASS v1550: experimental native record validator accepted'
