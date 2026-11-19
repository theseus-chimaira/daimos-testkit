#!/bin/sh
# v1659 source-linked native PDP-6 MM bitmap capacity and refusal probe.
set -eu
: "${DAIMOS_REPO:?source DAIMOS worktree required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-pure-bitmap-probe-v1659.XXXXXX")
trap 'echo "v1659 native evidence: $work"' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381"

# The installed codec must be the same 30 native instructions as v1451.
# Detect an accidental codec fork before accepting any MM probe result.
python3 - "$src/proc/proc_pure_bitmap_codec_v1659.s" \
    "$kit/tests/validation/d6codec-compressor-v1451/bitmap-v1451.s" <<'PY'
from pathlib import Path
import sys


def instructions(path):
    text = Path(path).read_text(encoding='ascii')
    if text.count('.text') != 1:
        raise ValueError('bitmap .text section mismatch')
    return [line.split(';', 1)[0].strip()
            for line in text.split('.text', 1)[1].splitlines()
            if line.split(';', 1)[0].strip()]


if instructions(sys.argv[1]) != instructions(sys.argv[2]):
    raise SystemExit('v1659 codec differs from native-tested v1451')
print('v1659: original v1451 codec instruction stream identical')
PY
"$PDP10_PREFIX/bin/das" -F -C -O "$work/bitmap.dobj" \
    "$src/proc/proc_pure_bitmap_codec_v1659.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h "$work/bitmap.dobj" \
    >"$work/bitmap-size.log"
grep -q '^sections: text=30 data=0 bss=0 ' "$work/bitmap-size.log"

# The separate allocator gate links the ACTUAL original MM source
# leaves, not the controlled native allocator used for C fault injection.
# It reproduces v1657's 883-word free gap with pinned RAW 06600 and
# verifies an exact 161-word disjoint owner plus unpin/free/shortage.
python3 - "$src/mm/mm_pdp6.s" "$work/real-mm.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='ascii')


def leaf(first, last):
    if source.count(first) != 1 or source.count(last) != 1:
        raise ValueError('v1659 original MM leaf boundary changed')
    return first + source.split(first, 1)[1].split(last, 1)[0]


decls = ('.text\n.globl mm_alloc_aligned_noreclaim\n'
         '.globl mm_extent_insert\n.globl mm_find_fit\n'
         '.globl mm_free\n.globl mm_pin\n.globl mm_unpin\n')
constants = '\n'.join(line for line in source.splitlines()
                      if line.startswith('        .equ    ')) + '\n'
body = (leaf('mm_delete:\n', '\n; Find a fitting free gap.') + '\n' +
        leaf('mm_find_fit:\n', '\n; int mm_alloc_aligned_noreclaim') + '\n' +
        leaf('mm_alloc_aligned_noreclaim:\n', '\n; Move one process extent') + '\n' +
        leaf('mm_free:\n', '\n; int mm_process_transfer_pinned') + '\n' +
        leaf('mm_pin_adjust:\n', '\n        .bss') + '\n')
for name in ('mm_find_base:', 'mm_extent_insert:', 'mm_alloc_nr_fit:',
             'mm_free_busy:', 'mm_pin_add_ok:', 'mm_pin_sub:'):
    if name not in body:
        raise ValueError('v1659 real MM missing original ' + name)
Path(sys.argv[2]).write_text(decls + constants + body, encoding='ascii')
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 30 \
    --workdir "$work/real-mm" --name pure-bitmap-real-mm-v1659 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/real-mm.s" "$here/real-mm-v1659.s" \
    >"$work/real-mm.log" 2>&1 || {
    tail -65 "$work/real-mm.log" >&2
    exit 1
}
echo 'v1659: ORIGINAL MM 883-gap/161-bitmap allocation, pin/free and shortage PASS'

# Two REAL, executed MM-assembler negative controls: the old type1..3
# check rejects a legitimate PACKED_PROCESS allocation, whereas an
# overbroad 3-bit check incorrectly accepts reserved type5..7 owners.
python3 - "$work/real-mm.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='ascii')
out = Path(sys.argv[2])
old = ('        tdne    012,[-10]\n'
       '        jrst    mm_alloc_nr_inval\n'
       '        caile   012,4\n'
       '        jrst    mm_alloc_nr_inval\n')
if source.count(old) != 1:
    raise SystemExit('v1659 original MM type guard drift')
out.joinpath('old-types.s').write_text(source.replace(old,
    '        tdne    012,[-4]\n'
    '        jrst    mm_alloc_nr_inval\n', 1), encoding='ascii')
out.joinpath('reserved-types.s').write_text(source.replace(old,
    '        tdne    012,[-10]\n'
    '        jrst    mm_alloc_nr_inval\n', 1), encoding='ascii')
PY
for mutant in old-types reserved-types; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 150000 --timeout 30 \
        --workdir "$work/real-mm-$mutant" --name "mm-$mutant-v1659" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/$mutant.s" "$here/real-mm-v1659.s" \
        >"$work/real-mm-$mutant.log" 2>&1; then
        echo "FAIL v1659: unsafe $mutant original MM mutation accepted" >&2
        exit 1
    fi
    if ! grep -q '^FAIL: __test_exit: got ' "$work/real-mm-$mutant.log"; then
        tail -60 "$work/real-mm-$mutant.log" >&2
        echo "FAIL v1659: $mutant did not reach native MM oracle" >&2
        exit 1
    fi
    echo "v1659: executed bad original MM $mutant guard rejected"
done

sh "$kit/tests/validation/pure-mm-owner-v1658/run-v1658.sh" >"$work/v1658.log" 2>&1
echo 'v1659: v1658 original MM/FULL/owner baseline PASS'

for spec in \
    'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' \
    'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384'; do
    set -- $spec
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$2"=1 $inc -S "$src/proc/$1.c" \
        -o "$work/$1.s" >"$work/$1.log" 2>&1 || {
        cat "$work/$1.log" >&2
        exit 1
    }
done
flags='-DDAIMOS_PURE_BITMAP_PROBE_V1659=1 -Dmm_alloc_aligned_noreclaim=mm_bmap_alloc_v1659 -Dmm_pin=mm_bmap_pin_v1659 -Dmm_unpin=mm_bmap_unpin_v1659 -Dmm_free=mm_bmap_free_v1659 -Dbitmap_encode_v1451=bitmap_encode_fault_v1659'
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $flags $inc \
    -S "$src/proc/proc_pure_bitmap_probe_v1659.c" \
    -o "$work/probe.s" >"$work/probe-compile.log" 2>&1 || {
    cat "$work/probe-compile.log" >&2
    exit 1
}
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$kit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    cat "$here/test-native-v1659.c"
} >"$work/test.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$work/test.c" -o "$work/test.s" \
    >"$work/test-compile.log" 2>&1 || {
    cat "$work/test-compile.log" >&2
    exit 1
}

run_guest() {
    name=$1
    candidate=$2
    target=$3
    mkdir -p "$work/$name"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/proc_pure_ram_v1381.s" \
        "$work/proc_pure_restore_v1384.s" \
        "$candidate" \
        "$src/proc/proc_pure_bitmap_codec_v1659.s" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" \
        "$work/test.s" >"$target" 2>&1
}
run_guest pure-bitmap-probe-v1659 "$work/probe.s" "$work/native.log" || {
    tail -80 "$work/native.log" >&2
    exit 1
}
echo 'v1659: original native bounded bitmap allocation, cleanup and faults PASS'

# Remove only the original stream verification, not the bitmap encoder.
# The poisoned output case MUST run and fail its native oracle.
python3 - "$src/proc/proc_pure_bitmap_probe_v1659.c" \
    "$work/unverified-probe.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = ('rc = pbmp_verify_v1659(data, raw, PBMP_PTR_V1659(target),\n'
       '            encoded);')
if s.count(old) != 1:
    raise SystemExit('v1659 bitmap verification mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old, 'rc = MM_OK;', 1), encoding='ascii')
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $flags $inc \
    -S "$work/unverified-probe.c" -o "$work/unverified-probe.s" \
    >"$work/mutant-compile.log" 2>&1 || {
    cat "$work/mutant-compile.log" >&2
    exit 1
}
if run_guest pure-bitmap-unverified-v1659 "$work/unverified-probe.s" \
    "$work/mutant.log"; then
    echo 'FAIL v1659: executed unverified bitmap mutant accepted' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got ' "$work/mutant.log"; then
    tail -50 "$work/mutant.log" >&2
    echo 'FAIL v1659: bitmap mutant did not execute native oracle' >&2
    exit 1
fi
echo 'v1659: executed unsafe bitmap validation bypass rejected'
