#!/bin/sh
# Source-linked real PDP-6 raw DTVOL2 DIRTY->CLEAN, physical I/O oracles.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-clean-native-v1566.XXXXXX")
if [ "${V1566_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/mkdtfs-v1566" \
    "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1566" --durable-v1550 -o "$work/clean-v1566.tap"

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(s) for s in sys.argv[1:])
image = (work / 'clean-v1566.tap').read_bytes()
mask = 0o777777777777
def words(data):
    assert len(data) == 1024
    result = []
    for offset in range(0, len(data), 8):
        high = int.from_bytes(data[offset:offset + 4], 'little')
        low = int.from_bytes(data[offset + 4:offset + 8], 'little')
        assert high <= 0o777777 and low <= 0o777777
        result.append((high << 18) | low)
    return result

clean = words(image[:1024])
assert clean[0] == 0o446466575422
assert clean[4] == 0
assert clean[5] == (~(clean[0] ^ clean[1] ^ clean[2] ^
                       0o246134572610) & mask)
dirty = clean[:]
dirty[4] = 0o552255225522
dirty[5] = (~(dirty[0] ^ dirty[1] ^ dirty[2] ^ dirty[4] ^
                       0o246134572610) & mask)
other = dirty[:]
other[1] = (other[1] + 1) & mask
other[3] = (~(other[0] ^ other[1] ^ other[2])) & mask
other[5] = (~(other[0] ^ other[1] ^ other[2] ^ other[4] ^
                      0o246134572610) & mask)

lines = ['.data\n.globl case_count_v1566\n.globl cases_v1566\n',
         '.globl record_clean_v1566\n.globl record_dirty_v1566\n',
         '.globl record_other_v1566\n']
for name, values in [('clean', clean), ('dirty', dirty), ('other', other)]:
    lines.append('record_%s_v1566:\n' % name)
    lines.extend('        .word 0%012o\n' % value for value in values)

# Mode, result, read attempts, write attempts, sticky poison callbacks,
# cache evictions, final physical RBN0 state. All values are data, not
# a model of the actual native transaction under test.
cases = []
def case(label, mode, ok=False, reads=1, writes=0, poison=1,
         evicts=1, final=None):
    if final is None:
        final = dirty[4]
    cases.append((label, [mode, 0 if ok else -1, reads, writes,
                          poison, evicts, final]))

case('DIRTY fully sealed CLEAN', 0, ok=True, reads=2, writes=1,
     poison=0, evicts=1, final=0)
case('never rewrite already CLEAN', 1, final=0)
case('valid foreign 72-bit volume refused', 2)
case('invalid salted DIRTY seal refused', 3)
case('invalid RBN0 padding refused', 4)
case('zero-byte falsely successful initial read refused', 5)
case('real initial physical read error refused', 6)
case('partial CLEAN write poisons mount', 7, reads=1, writes=1,
     evicts=2, final=0)
case('write ACK with no media change poisons', 0o10, reads=2,
     writes=1, evicts=2)
case('physical readback error poisons', 0o11, reads=2, writes=1,
     evicts=2, final=0)
case('empty readback falsely succeeded poisons', 0o12, reads=2,
     writes=1, evicts=2, final=0)
case('wrong expected HIGH volume ID refused', 0o13)
case('wrong expected LOW volume ID refused', 0o14)
case('null scratch refused pre-I/O', 0o15, reads=0, poison=0, evicts=0)
case('zero HIGH ID refused pre-I/O', 0o16, reads=0, poison=0, evicts=0)
case('zero LOW ID refused pre-I/O', 0o17, reads=0, poison=0, evicts=0)
case('volume HIGH changed after physical write', 0o20, reads=2,
     writes=1, evicts=2, final=0)
case('volume LOW changed after physical write', 0o21, reads=2,
     writes=1, evicts=2, final=0)

lines.append('.equ case_count_v1566,0%o\ncases_v1566:\n' % len(cases))
for label, fields in cases:
    lines.append('        ; %s\n' % label)
    lines.extend('        .word %s\n' %
                 ('-1' if value == -1 else '0%012o' % value)
                 for value in fields)
(work / 'real-v2-cases-v1566.s').write_text(''.join(lines))

source = (repo / 'system/kernel/fs/dtfs_intent_clean_v1566.s').read_text()
mutants = (
    ('accept-CLEAN-initial',
     'caie    1,1                     ; MUST be WRITE_INTENT, not CLEAN',
     'caie    1,0                     ; mistakenly accepts CLEAN'),
    ('skip-pre-read-wipe',
     'pushj   17,dtfs_clean_wipe_v1566',
     'move    2,2                     ; accepts reused old DIRTY scratch'),
    ('skip-readback-wipe',
     '; New physical readback, not a comparison to the old MM buffer.\n'
     '        pushj   17,dtfs_clean_wipe_v1566',
     '; New physical readback, not a comparison to the old MM buffer.\n'
     '        move    2,2                 ; stale CLEAN accepted'),
    ('skip-real-write',
     'pushj   17,dtfs_dtc_write_jump',
     'setz    1,                      ; not physically written'),
    ('ignore-write-error',
     'pushj   17,dtfs_dtc_write_jump\n'
     '        jumpn   1,dtfs_clean_uncertain_v1566',
     'pushj   17,dtfs_dtc_write_jump\n'
     '        jumpe   1,dtfs_clean_uncertain_v1566'),
    ('skip-real-readback',
     '; New physical readback, not a comparison to the old MM buffer.\n'
     '        pushj   17,dtfs_clean_wipe_v1566\n'
     '        move    1,010\n'
     '        setz    2,\n'
     '        move    3,013\n'
     '        pushj   17,dtfs_dtc_read_jump',
     '; New physical readback, not a comparison to the old MM buffer.\n'
     '        pushj   17,dtfs_clean_wipe_v1566\n'
     '        move    1,010\n'
     '        setz    2,\n'
     '        move    3,013\n'
     '        setz    1,             ; no physical readback'),
    ('no-cache-eviction',
     'pushj   17,bcache_invalidate_all',
     'move    2,2                   ; never clear cached metadata'),
    ('no-sticky-uncertainty',
     'pushj   17,dtfs_mark_unit_suspect_v1522',
     'move    2,2                   ; forgot sticky poison'),
    ('wrong-CLEAN-seal-salt',
     'xor     1,[0246134572610]',
     'xor     1,[0246134572611]'),
    ('skip-high-identity',
     'came    2,1(013)\n        jrst    dtfs_clean_uncertain_v1566',
     'move    2,2\n        jrst    dtfs_clean_high_ok_v1566\n'
     'dtfs_clean_high_ok_v1566:'),
    ('skip-low-identity',
     'came    2,2(013)\n        jrst    dtfs_clean_uncertain_v1566',
     'move    2,2\n        jrst    dtfs_clean_low_ok_v1566\n'
     'dtfs_clean_low_ok_v1566:'),
)
for name, old, new in mutants:
    assert source.count(old) == (2 if name in ('skip-high-identity',
                                              'skip-low-identity',
                                              'skip-pre-read-wipe',
                                              'no-cache-eviction') else 1), (
        name, source.count(old))
    # Identity-skipping replacements need unique labels, because they
    # occur both before raw WRITE and after its physical readback.
    if name in ('skip-high-identity','skip-low-identity'):
        source_mut = source.replace(old, new, 1)
        source_mut = source_mut.replace(old, new.replace('_ok_v1566:',
            '_readback_ok_v1566:').replace('_ok_v1566\n',
            '_readback_ok_v1566\n'), 1)
    else:
        source_mut = source.replace(old, new, 1)
    (work / ('unsafe-%s-v1566.s' % name)).write_text(source_mut)
print('v1566: %d real-image native cases, %d unsafe source mutations' %
      (len(cases), len(mutants)))
PY

run_case() {
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 450000 --timeout 20 \
        --workdir "$work/run-$name" --name "dtfs-clean-$name-v1566" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-clean-native-v1566.s" \
        "$work/real-v2-cases-v1566.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" \
        "$source" > "$work/$name.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_clean_v1566.s"; then
    tail -85 "$work/baseline.log" >&2
    echo 'FAIL v1566: physical read, write, readback source contract' >&2
    exit 1
fi
echo 'PASS v1566: 18 real-image native DIRTY/CLEAN, failure and partial I/O'
for name in accept-CLEAN-initial skip-pre-read-wipe skip-readback-wipe \
    skip-real-write ignore-write-error skip-real-readback \
    no-cache-eviction no-sticky-uncertainty wrong-CLEAN-seal-salt \
    skip-high-identity skip-low-identity; do
    if run_case "$name" "$work/unsafe-$name-v1566.s"; then
        echo "FAIL v1566: unsafe physical CLEAN mutant accepted: $name" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$name.log" || {
        tail -50 "$work/$name.log" >&2
        echo "FAIL v1566: mutant did not reach native oracle: $name" >&2
        exit 1
    }
    echo "PASS v1566: rejected unsafe $name"
done
echo 'PASS v1566: raw RBN0 CLEAN seal preserves exact physical identity'
