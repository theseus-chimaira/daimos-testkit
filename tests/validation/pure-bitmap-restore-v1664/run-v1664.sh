#!/bin/sh
# v1664: PDP-6 source-linked bounded compressed FULL restore tests.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-restore-v1664.XXXXXX")
trap 'echo "v1664 FULL restore evidence: $work"' EXIT HUP INT TERM
inc="-I$here -I$kit/tests/validation/pure-bitmap-compress-v1663 -I$kit/tests/validation/pure-bitmap-commit-v1662 -I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

if [ "${V1664_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-bitmap-compress-v1663/run-v1663.sh" \
        >"$work/v1663-baseline.log" 2>&1
    echo 'v1664: original v1663/v1662/v1661/v1660/v1659 native baseline PASS'
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
build_c restore "$src/proc/proc_pure_bitmap_restore_v1664.c" \
    -DDAIMOS_PBR_V1664=1 \
    -Dmm_alloc_aligned_noreclaim=mm_restore_alloc_v1664 \
    -Dmm_pin=mm_restore_pin_v1664 -Dmm_unpin=mm_restore_unpin_v1664 \
    -Dmm_free=mm_restore_free_v1664 \
    -Dmm_pure_bitmap_finish_v1664=mm_finish_hook_v1664
python3 - "$kit/tests/validation/pure-bitmap-commit-v1662/test-native-v1662.c" \
    "$kit/tests/validation/pure-bitmap-compress-v1663/test-native-v1663.c" \
    "$here/test-native-v1664.c" "$work/native-merged.c" <<'PY'
from pathlib import Path
import sys
base = Path(sys.argv[1]).read_text(encoding='ascii')
front = Path(sys.argv[2]).read_text(encoding='ascii')
new = Path(sys.argv[3]).read_text(encoding='ascii')
old = 'int\nmain(void)\n'
if any(x.count(old) != 1 for x in (base, front, new)):
    raise SystemExit('v1664 native main rename source drift')
base = base.replace(old, 'int\nretired_main_v1662(void)\n', 1)
front = front.replace(old, 'int\nretired_main_v1663(void)\n', 1)
Path(sys.argv[4]).write_text('#include "mm_internal.h"\n' +
                             base + '\n' + front + '\n' + new,
                             encoding='ascii')
PY
build_c test "$work/native-merged.c"

"$PDP10_PREFIX/bin/das" -F -C -O "$work/restore.dobj" \
    "$work/restore.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/finish.dobj" \
    "$src/mm/mm_pure_bitmap_finish_v1664.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/restore.dobj" >"$work/restore-size.log"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/finish.dobj" >"$work/finish-size.log"

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
        "$src/mm/mm_pure_bitmap_finish_v1664.s" \
        "$src/proc/proc_pure_bitmap_codec_v1659.s" \
        "$work/commit.s" "$work/terminal.s" "$work/decode.s" \
        "$work/compress.s" "$candidate" "$work/test.s" \
        >"$log" 2>&1
}

run_guest bitmap-restore-v1664 "$work/restore.s" "$work/native.log" || {
    tail -90 "$work/native.log" >&2
    exit 1
}
echo 'v1664: real MM compressed->APR FULL restore and negative cases PASS'

# Unsafe mutation 1: bypass FULL compressed-stream preflight. A
# malformed literal must never become a RESIDENT owner.
python3 - "$src/proc/proc_pure_bitmap_restore_v1664.c" \
    "$work/unsafe-decode.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = ('rc = proc_pure_bitmap_decode_v1660(source, encoded,\n'
       '            target + skip, raw);')
if s.count(old)!=1:
    raise SystemExit('v1664 decoder mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old, 'rc = MM_OK;', 1),
                              encoding='ascii')
PY
build_c unsafe-decode "$work/unsafe-decode.c" \
    -DDAIMOS_PBR_V1664=1 \
    -Dmm_alloc_aligned_noreclaim=mm_restore_alloc_v1664 \
    -Dmm_pin=mm_restore_pin_v1664 -Dmm_unpin=mm_restore_unpin_v1664 \
    -Dmm_free=mm_restore_free_v1664 \
    -Dmm_pure_bitmap_finish_v1664=mm_finish_hook_v1664
if run_guest bitmap-restore-decode-mutant-v1664 \
    "$work/unsafe-decode.s" "$work/mutant-decode.log"; then
    echo 'FAIL v1664: unchecked bitmap FULL restore accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant-decode.log" || {
    tail -65 "$work/mutant-decode.log" >&2
    exit 1
}
echo 'v1664: executed unchecked bitmap FULL restore mutant rejected'

# Unsafe mutation 2: ignore a third packed MM owner in the atomic
# source-delete leaf. Direct ASM native oracle must reject.
python3 - "$src/mm/mm_pure_bitmap_finish_v1664.s" \
    "$work/unsafe-finish.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='ascii')
old='jumpge  016,mbf_bad_v1664     ; duplicate packed owner'
if s.count(old)!=1:
    raise SystemExit('v1664 MM finish mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old,
    'jumpge  016,mbf_next_v1664    ; unsafe ignore duplicate',1),
    encoding='ascii')
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/bitmap-finish-owner-mutant-v1664" \
    --name bitmap-finish-owner-mutant-v1664 --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/real-mm.s" "$work/storage-expect.s" \
    "$src/mm/mm_pure_bitmap_retire_v1662.s" "$work/unsafe-finish.s" \
    "$src/proc/proc_pure_bitmap_codec_v1659.s" \
    "$work/commit.s" "$work/terminal.s" "$work/decode.s" \
    "$work/compress.s" "$work/restore.s" "$work/test.s" \
    >"$work/mutant-owner.log" 2>&1 && {
    echo 'FAIL v1664: unsafe extra packed owner was accepted' >&2
    exit 1
}
grep -q '^FAIL: __test_exit: got ' "$work/mutant-owner.log" || {
    tail -65 "$work/mutant-owner.log" >&2
    exit 1
}
echo 'v1664: executed duplicate-MM-owner finish mutant rejected'
