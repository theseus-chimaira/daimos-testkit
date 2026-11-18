#!/bin/sh
# v1662 PDP-6 source-linked prepared bitmap MM + mode3 atomic commit.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-commit-v1662.XXXXXX")
trap 'echo "v1662 commit evidence: $work"' EXIT HUP INT TERM
inc="-I$here -I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

if [ "${V1662_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-bitmap-terminal-v1661/run-v1661.sh" \
        >"$work/v1661-baseline.log" 2>&1
    echo 'v1662: original v1661/v1660/v1659 native baseline PASS'
fi

# Reuse exact original permanent MM allocation/free/pin leaves and
# fixed mode2 expectation leaf; never rewrite either API in C.
python3 - "$src/mm/mm_pdp6.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$work/real-mm.s" "$work/storage-expect.s" <<'PY'
from pathlib import Path
import sys
mm = Path(sys.argv[1]).read_text(encoding='ascii')
storage = Path(sys.argv[2]).read_text(encoding='ascii')


def leaf(s, start, stop):
    if s.count(start) != 1 or s.count(stop) != 1:
        raise SystemExit('v1662 ORIGINAL MM/storage source drift')
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
        raise SystemExit('v1662 original MM missing ' + symbol)
constants = '\n'.join(line for line in mm.splitlines()
                      if line.startswith('        .equ    ')) + '\n'
Path(sys.argv[3]).write_text(
    '.text\n.globl mm_free\n.globl mm_alloc_aligned_noreclaim\n'
    '.globl mm_pin\n.globl mm_unpin\n' + constants + body,
    encoding='ascii')
body = leaf(storage, 'proc_storage_expect_v30:\n',
            '\nproc_storage_publish_v30:')
if 'proc_storage_good_v30:' not in body:
    raise SystemExit('v1662 original storage expectation drift')
Path(sys.argv[4]).write_text(
    '.text\n.globl proc_storage_expect_v30\n'
    '.globl proc_storage_runtime_v29\n' + body,
    encoding='ascii')
PY

build_c() {
    name=$1
    input=$2
    shift 2
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        "$@" $inc -S "$input" -o "$work/$name.s" \
        >"$work/$name-build.log" 2>&1 || {
        tail -70 "$work/$name-build.log" >&2
        exit 1
    }
}

build_c bitmap-commit "$src/proc/proc_pure_bitmap_commit_v1662.c" \
    -DDAIMOS_PURE_BITMAP_COMMIT_V1662=1 \
    -Dmm_pure_bitmap_retire_v1662=mm_bitmap_retire_hook_v1662
build_c bitmap-terminal "$src/proc/proc_pure_bitmap_terminal_v1661.c" \
    -DDAIMOS_PURE_BITMAP_TERMINAL_V1661=1 \
    -Dmm_free=mm_terminal_free_v1661
build_c bitmap-decode "$src/proc/proc_pure_bitmap_decode_v1660.c" \
    -DDAIMOS_PURE_BITMAP_DECODE_V1660=1
build_c native-test "$here/test-native-v1662.c"

"$PDP10_PREFIX/bin/das" -F -C -O "$work/bitmap-retire.dobj" \
    "$src/mm/mm_pure_bitmap_retire_v1662.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/bitmap-commit.dobj" \
    "$work/bitmap-commit.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/bitmap-retire.dobj" >"$work/retire-size.log"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/bitmap-commit.dobj" >"$work/commit-size.log"

run_guest() {
    name=$1
    candidate_c=$2
    candidate_mm=$3
    log=$4
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/real-mm.s" "$work/storage-expect.s" \
        "$candidate_mm" \
        "$src/proc/proc_pure_bitmap_codec_v1659.s" \
        "$work/bitmap-terminal.s" "$work/bitmap-decode.s" \
        "$candidate_c" "$work/native-test.s" >"$log" 2>&1
}

run_guest bitmap-commit-v1662 "$work/bitmap-commit.s" \
    "$src/mm/mm_pure_bitmap_retire_v1662.s" "$work/native.log" || {
    tail -65 "$work/native.log" >&2
    exit 1
}
echo 'v1662: native real-MM allocation/pin/free mode2 -> mode3 -> terminal PASS'

# Negative control 1: skipping the full bitmap/raw comparison must
# be detected by the independent native corrupt-stream oracle.
python3 - "$src/proc/proc_pure_bitmap_commit_v1662.c" \
    "$work/unsafe-commit.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = ('rc = pbc_exact_v1662(PBC_PTR_V1662(raw_base), raw,\n'
       '            PBC_PTR_V1662(encoded_base), encoded_words);')
if s.count(old) != 1:
    raise SystemExit('v1662 exact bitmap mutation anchor drift')
Path(sys.argv[2]).write_text(s.replace(old, 'rc = MM_OK;', 1),
                             encoding='ascii')
PY
build_c unsafe-commit "$work/unsafe-commit.c" \
    -DDAIMOS_PURE_BITMAP_COMMIT_V1662=1 \
    -Dmm_pure_bitmap_retire_v1662=mm_bitmap_retire_hook_v1662
if run_guest bitmap-commit-stream-mutant-v1662 \
    "$work/unsafe-commit.s" \
    "$src/mm/mm_pure_bitmap_retire_v1662.s" \
    "$work/mutant-stream.log"; then
    echo 'FAIL v1662: unchecked stream commit mutant accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant-stream.log" || {
    tail -55 "$work/mutant-stream.log" >&2
    exit 1
}
echo 'v1662: executed unchecked stream mutant rejected'

# Negative control 2: deleting source despite a third packed process
# owner must fail the DIRECT assembly oracle, not merely the C guard.
python3 - "$src/mm/mm_pure_bitmap_retire_v1662.s" \
    "$work/unsafe-retire.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = 'jrst    mm_bitmap_bad_v1662     ; third PACKED owner'
if s.count(old) != 1:
    raise SystemExit('v1662 native MM uniqueness mutation anchor drift')
s = s.replace(old, 'jrst    mm_bitmap_next_v1662    ; unsafe ignore extra', 1)
Path(sys.argv[2]).write_text(s, encoding='ascii')
PY
if run_guest bitmap-retire-owner-mutant-v1662 \
    "$work/bitmap-commit.s" "$work/unsafe-retire.s" \
    "$work/mutant-owner.log"; then
    echo 'FAIL v1662: duplicate MM owner mutant accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant-owner.log" || {
    tail -55 "$work/mutant-owner.log" >&2
    exit 1
}
echo 'v1662: executed duplicate-owner MM-assembler mutant rejected'
