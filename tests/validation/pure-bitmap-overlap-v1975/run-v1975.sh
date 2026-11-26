#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel/proc"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-overlap-v1975.XXXXXX")
trap 'echo "v1975 evidence: $work"' EXIT
compile() {
    "${KCC:-$PDP10_PREFIX/bin/kcc}" -Pgnu99 -O -x=pdp6 -m=gas \
        -I"$src" -I"$DAIMOS_REPO/system/kernel/mm" \
        -I"$DAIMOS_REPO/system/kernel/core" -I"$PDP10_PREFIX/include" \
        -S "$1" -o "$2"
}
compile "$src/proc_pure_bitmap_overlap_v1975.c" "$work/codec.s"
compile "$here/test-native-v1975.c" "$work/test.s"
run_guest() {
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 45 \
        --workdir "$work/$1" --name "$1" --expect __test_exit=0 \
        --examine diag_raw_v1975 --examine diag_pattern_v1975 \
        --examine diag_delta_v1975 --examine diag_rc_v1975 \
        --examine diag_good_v1975 --examine diag_refused_v1975 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$src/proc_pure_bitmap_codec_v1659.s" "$2" "$work/test.s"
}
run_guest bitmap-overlap-v1975 "$work/codec.s" >"$work/native.log" 2>&1 || {
    tail -70 "$work/native.log"; exit 1;
}
tail -20 "$work/native.log"
# Independently remove the encoder and decoder unread-input checks.
for side in encode decode; do
    python3 - "$src/proc_pure_bitmap_overlap_v1975.c" "$work/$side.c" "$side" <<'PY2'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
anchor = 'if (hazard)'
assert s.count(anchor) == 2
head, sep, tail = s.partition('pbm_decode_v1975(')
if sys.argv[3] == 'encode':
    head = head.replace(anchor, 'if (0)', 1)
else:
    tail = tail.replace(anchor, 'if (0)', 1)
Path(sys.argv[2]).write_text(head + sep + tail, encoding='ascii')
PY2
    compile "$work/$side.c" "$work/$side.s"
    if run_guest "bitmap-$side-mutant-v1975" "$work/$side.s" >"$work/$side.log" 2>&1; then
        echo "FAIL: unsafe $side overlap mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$side.log"
done
echo 'v1975: native overlap matrix and both executed unsafe-overlap mutants PASS'
