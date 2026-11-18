#!/bin/sh
# v1663: PDP-6 real-MM compressor allocation/commit/cleanup fault test.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-compress-v1663.XXXXXX")
trap 'echo "v1663 compressor evidence: $work"' EXIT HUP INT TERM
inc="-I$here -I$kit/tests/validation/pure-bitmap-commit-v1662 -I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

if [ "${V1663_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-bitmap-commit-v1662/run-v1662.sh" \
        >"$work/v1662-baseline.log" 2>&1
    echo 'v1663: original v1662/v1661/v1660/v1659 native baseline PASS'
fi

# Exact source-extracted original MM fit, allocation, insert, pin,
# unpin and free; plus original immutable mode2 expectation.
python3 - "$src/mm/mm_pdp6.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$work/real-mm.s" "$work/storage-expect.s" <<'PY'
from pathlib import Path
import sys
mm = Path(sys.argv[1]).read_text(encoding='ascii')
storage = Path(sys.argv[2]).read_text(encoding='ascii')


def leaf(s, start, stop):
    if s.count(start) != 1 or s.count(stop) != 1:
        raise SystemExit('v1663 original MM/storage leaf boundary drift')
    return start + s.split(start, 1)[1].split(stop, 1)[0]


body = leaf(mm, 'mm_delete:\n', '\n; Find a fitting free gap.')
body += '\n' + leaf(mm, 'mm_find_fit:\n',
                      '\n; int mm_alloc_aligned_noreclaim')
body += '\n' + leaf(mm, 'mm_alloc_aligned_noreclaim:\n',
                      '\n; Move one process extent')
body += '\n' + leaf(mm, 'mm_free:\n',
                      '\n; int mm_process_transfer_pinned')
body += '\n' + leaf(mm, 'mm_pin_adjust:\n', '\n        .bss')
for symbol in ('mm_delete:', 'mm_find_base:', 'mm_find_fit:',
               'mm_alloc_aligned_noreclaim:', 'mm_extent_insert:',
               'mm_free:', 'mm_pin:', 'mm_unpin:'):
    if symbol not in body:
        raise SystemExit('v1663 missing original ' + symbol)
constants = '\n'.join(line for line in mm.splitlines()
                      if line.startswith('        .equ    ')) + '\n'
Path(sys.argv[3]).write_text(
    '.text\n.globl mm_free\n.globl mm_alloc_aligned_noreclaim\n'
    '.globl mm_pin\n.globl mm_unpin\n' + constants + body,
    encoding='ascii')
body = leaf(storage, 'proc_storage_expect_v30:\n',
            '\nproc_storage_publish_v30:')
if 'proc_storage_good_v30:' not in body:
    raise SystemExit('v1663 storage mode expectation drift')
Path(sys.argv[4]).write_text(
    '.text\n.globl proc_storage_expect_v30\n'
    '.globl proc_storage_runtime_v29\n' + body,
    encoding='ascii')
PY

build_c() {
    name=$1
    source=$2
    shift 2
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        "$@" $inc -S "$source" -o "$work/$name.s" \
        >"$work/$name-build.log" 2>&1 || {
        tail -80 "$work/$name-build.log" >&2
        exit 1
    }
}

front_flags='-DDAIMOS_PBF_V1663=1 -Dmm_alloc_aligned_noreclaim=mm_front_alloc_v1663 -Dmm_pin=mm_front_pin_v1663 -Dmm_unpin=mm_front_unpin_v1663 -Dmm_free=mm_front_free_v1663 -Dbitmap_encode_v1451=bitmap_front_encode_v1663'
build_c compress "$src/proc/proc_pure_bitmap_compress_v1663.c" \
    $front_flags
build_c commit "$src/proc/proc_pure_bitmap_commit_v1662.c" \
    -DDAIMOS_PURE_BITMAP_COMMIT_V1662=1 \
    -Dmm_pure_bitmap_retire_v1662=mm_bitmap_retire_hook_v1662
build_c terminal "$src/proc/proc_pure_bitmap_terminal_v1661.c" \
    -DDAIMOS_PURE_BITMAP_TERMINAL_V1661=1 \
    -Dmm_free=mm_terminal_free_v1661
build_c decode "$src/proc/proc_pure_bitmap_decode_v1660.c" \
    -DDAIMOS_PURE_BITMAP_DECODE_V1660=1
python3 - "$kit/tests/validation/pure-bitmap-commit-v1662/test-native-v1662.c" \
    "$here/test-native-v1663.c" "$work/native-merged.c" <<'PY'
from pathlib import Path
import sys
base = Path(sys.argv[1]).read_text(encoding='ascii')
new = Path(sys.argv[2]).read_text(encoding='ascii')
old = 'int\nmain(void)\n'
if base.count(old) != 1 or new.count(old) != 1:
    raise SystemExit('v1663 native main rename source drift')
base = base.replace(old, 'int\nretired_main_v1662(void)\n', 1)
Path(sys.argv[3]).write_text('#include "mm_internal.h"\n' +
                             base + '\n' + new, encoding='ascii')
PY
build_c test "$work/native-merged.c"

"$PDP10_PREFIX/bin/das" -F -C -O "$work/compress.dobj" \
    "$work/compress.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/compress.dobj" >"$work/compress-size.log"

run_guest() {
    name=$1
    candidate=$2
    log=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/real-mm.s" "$work/storage-expect.s" \
        "$src/mm/mm_pure_bitmap_retire_v1662.s" \
        "$src/proc/proc_pure_bitmap_codec_v1659.s" \
        "$work/commit.s" "$work/terminal.s" "$work/decode.s" \
        "$candidate" "$work/test.s" >"$log" 2>&1
}

run_guest bitmap-compress-v1663 "$work/compress.s" "$work/native.log" || {
    tail -65 "$work/native.log" >&2
    exit 1
}
echo 'v1663: original MM allocation/encode/commit/rollback native PASS'

# Disable ALL destination geometry checks before encoding: a forged
# allocator witness may then overwrite RAW in native guest memory.
python3 - "$src/proc/proc_pure_bitmap_compress_v1663.c" \
    "$work/unsafe-geometry.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = ('if (!target || target > MM_HALF_MASK ||\n'
       '            encoded > MM_HALF_MASK + 1UL - target ||\n'
       '            (source < target + encoded && target < source + raw) ||\n'
       '            pbf_owners_v1663(slot, source, raw, 1U,\n'
       '                target, encoded, 0U) != MM_OK)\n'
       '                return MM_ERR_BUSY;')
if s.count(old) != 1:
    raise SystemExit('v1663 target admission mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old,
    'if (0)\n                return MM_ERR_BUSY;', 1),
    encoding='ascii')
PY
build_c unsafe-geometry "$work/unsafe-geometry.c" $front_flags
if run_guest bitmap-compress-geometry-mutant-v1663 \
    "$work/unsafe-geometry.s" "$work/mutant-geometry.log"; then
    echo 'FAIL v1663: unsafe encoded target geometry accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant-geometry.log" || {
    tail -65 "$work/mutant-geometry.log" >&2
    exit 1
}
echo 'v1663: executed unsafe allocator geometry mutant rejected'

# Pretend successful destination unpin; real MM still retains one pin,
# so neither v1662 commit nor the frontend may publish mode3.
python3 - "$src/proc/proc_pure_bitmap_compress_v1663.c" \
    "$work/unsafe-unpin.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = 'if (mm_unpin(target) != MM_OK)\n                return MM_ERR_BUSY;'
if s.count(old) != 1:
    raise SystemExit('v1663 target unpin mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old,
    'if (0)\n                return MM_ERR_BUSY;', 1),
    encoding='ascii')
PY
build_c unsafe-unpin "$work/unsafe-unpin.c" $front_flags
if run_guest bitmap-compress-unpin-mutant-v1663 \
    "$work/unsafe-unpin.s" "$work/mutant-unpin.log"; then
    echo 'FAIL v1663: unsafe destination unpin bypass accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant-unpin.log" || {
    tail -65 "$work/mutant-unpin.log" >&2
    exit 1
}
echo 'v1663: executed unsafe target unpin mutant rejected'
