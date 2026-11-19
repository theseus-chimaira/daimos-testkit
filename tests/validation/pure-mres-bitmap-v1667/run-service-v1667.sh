#!/bin/sh
# v1667 original v1664 source-linked MM + PURE service mode3 RUN.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-pure-service-v1667.XXXXXX")
trap 'echo "v1667 source-linked service evidence: $work"' EXIT HUP INT TERM
inc="-I$here -I$kit/tests/validation/pure-bitmap-restore-v1664 -I$kit/tests/validation/pure-bitmap-compress-v1663 -I$kit/tests/validation/pure-bitmap-commit-v1662 -I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

V1664_SKIP_BASELINE=1 sh \
    "$kit/tests/validation/pure-bitmap-restore-v1664/run-v1664.sh" \
    >"$work/v1664-original-native.log" 2>&1 || {
    tail -80 "$work/v1664-original-native.log" >&2
    exit 1
}
base=$(sed -n 's/^v1664 FULL restore evidence: //p' \
    "$work/v1664-original-native.log" | tail -1)
if [ ! -s "$base/native-merged.c" ] || \
    [ ! -s "$base/real-mm.s" ] || [ ! -s "$base/restore.s" ]; then
    echo 'v1667: original v1664 native source fixture unavailable' >&2
    exit 1
fi
echo 'v1667: genuine original v1664 source-linked MM baseline PASS'

python3 - "$base/native-merged.c" "$here/test-service-v1667.c" \
    "$work/merged.c" <<'PY'
from pathlib import Path
import sys
old=Path(sys.argv[1]).read_text(encoding='ascii')
new=Path(sys.argv[2]).read_text(encoding='ascii')
needle='int\nmain(void)\n'
if old.count(needle)!=1 or new.count(needle)!=1:
    raise SystemExit('v1667 original FULL restore fixture drift')
Path(sys.argv[3]).write_text(old.replace(needle,
    'int\nretired_v1664_main(void)\n',1)+'\n'+new,
    encoding='ascii')
PY

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$work/merged.c" -o "$work/service-test.s" \
    >"$work/service-test-build.log" 2>&1 || {
    tail -80 "$work/service-test-build.log" >&2; exit 1;
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -DDAIMOS_PBM_V1667=1 -S \
    "$src/proc/proc_pure_service_pdp6_v1612.c" \
    -o "$work/pure-service.s" >"$work/pure-service-build.log" 2>&1 || {
    tail -80 "$work/pure-service-build.log" >&2; exit 1;
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -DDAIMOS_PBR_V1664=1 -DDAIMOS_PBM_V1667=1 \
    -Dmm_alloc_aligned_noreclaim=mm_restore_alloc_v1664 \
    -Dmm_pin=mm_restore_pin_v1664 \
    -Dmm_unpin=mm_restore_unpin_v1664 \
    -Dmm_free=mm_restore_free_v1664 \
    -Dmm_pure_bitmap_finish_v1664=mm_finish_hook_v1664 \
    -S "$src/proc/proc_pure_bitmap_restore_v1664.c" \
    -o "$work/bitmap-restore-v1667.s" \
    >"$work/bitmap-restore-build.log" 2>&1 || {
    tail -80 "$work/bitmap-restore-build.log" >&2; exit 1;
}

run_native() {
    name=$1
    restore=$2
    log=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$base/real-mm.s" "$base/storage-expect.s" \
        "$src/mm/mm_pure_bitmap_retire_v1662.s" \
        "$src/mm/mm_pure_bitmap_finish_v1664.s" \
        "$src/proc/proc_pure_bitmap_codec_v1659.s" \
        "$base/commit.s" "$base/terminal.s" "$base/decode.s" \
        "$base/compress.s" "$restore" \
        "$work/pure-service.s" "$work/service-test.s" >"$log" 2>&1
}
run_native pure-bitmap-service-v1667 \
    "$work/bitmap-restore-v1667.s" "$work/native.log" || {
    tail -95 "$work/native.log" >&2; exit 1;
}
echo 'v1667: original-MM PURE scheduler mode3 FULL restore native PASS'

# Unsafe mutation: the retry guard must not clear TRANSITION when an
# aborted FULL restore has a second, incorrectly pinned APR owner.
# Preserve all normal restore logic; only weaken the retry MM proof.
python3 - "$src/proc/proc_pure_bitmap_restore_v1664.c" \
    "$work/unsafe-retry.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='ascii')
old=('pbr_source_v1664(slot, words - skip, &source,\n'
     '                &encoded) != MM_OK)')
finish=('return pbr_owners_v1664(slot, source, encoded, 0U,\n'
        '            0UL, 0UL, 0U);')
if s.count(old)!=1 or s.count(finish)!=1:
    raise SystemExit('v1667 retry MM ownership mutant source drift')
s=s.replace(old,'0)',1).replace(finish,'return MM_OK;',1)
Path(sys.argv[2]).write_text(s,encoding='ascii')
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -DDAIMOS_PBR_V1664=1 -DDAIMOS_PBM_V1667=1 \
    -Dmm_alloc_aligned_noreclaim=mm_restore_alloc_v1664 \
    -Dmm_pin=mm_restore_pin_v1664 \
    -Dmm_unpin=mm_restore_unpin_v1664 \
    -Dmm_free=mm_restore_free_v1664 \
    -Dmm_pure_bitmap_finish_v1664=mm_finish_hook_v1664 \
    -S "$work/unsafe-retry.c" -o "$work/unsafe-retry.s" \
    >"$work/unsafe-retry-build.log" 2>&1 || {
    tail -80 "$work/unsafe-retry-build.log" >&2; exit 1;
}
if run_native pure-bitmap-retry-mutant-v1667 \
    "$work/unsafe-retry.s" "$work/mutant-retry.log"; then
    echo 'FAIL v1667: unsafe retry cleared quarantined TRANSITION' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant-retry.log" || {
    tail -75 "$work/mutant-retry.log" >&2; exit 1;
}
echo 'v1667: executed unsafe bitmap retry-owner mutant rejected'
