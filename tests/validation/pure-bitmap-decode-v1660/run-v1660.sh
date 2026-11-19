#!/bin/sh
# PDP-6 native decoder preflight, no installed compressed owner.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel/proc"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-decode-v1660.XXXXXX")
trap 'echo "v1660 decoder evidence: $work"' EXIT HUP INT TERM

if [ "${V1660_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-bitmap-probe-v1659/run-v1659.sh" \
        >"$work/v1659.log" 2>&1
    echo 'v1660: v1659 native bitmap and original MM baseline PASS'
fi

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_PURE_BITMAP_DECODE_V1660=1 \
    -I"$src" -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$PDP10_PREFIX/include" \
    -S "$src/proc_pure_bitmap_decode_v1660.c" \
    -o "$work/decoder.s" >"$work/decoder-compile.log" 2>&1 || {
    cat "$work/decoder-compile.log" >&2
    exit 1
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$src" -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$PDP10_PREFIX/include" \
    -S "$here/test-native-v1660.c" -o "$work/test.s" \
    >"$work/test-compile.log" 2>&1 || {
    cat "$work/test-compile.log" >&2
    exit 1
}

run_guest() {
    name=$1
    decoder=$2
    log=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" \
        --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$src/proc_pure_bitmap_codec_v1659.s" \
        "$decoder" "$work/test.s" >"$log" 2>&1
}
run_guest bitmap-decode-v1660 "$work/decoder.s" "$work/native.log" || {
    tail -60 "$work/native.log" >&2
    exit 1
}
echo 'v1660: native preflight/decoded output and no-write corrupt cases PASS'

python3 - "$src/proc_pure_bitmap_decode_v1660.c" \
    "$work/unverified.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = 'if (offset != encoded_words)\n                return MM_ERR_INVAL;'
if s.count(old) != 1:
    raise SystemExit('v1660 source preflight mutation anchor drift')
s = s.replace(old, 'if (0)\n                return MM_ERR_INVAL;', 1)
Path(sys.argv[2]).write_text(s, encoding='ascii')
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_PURE_BITMAP_DECODE_V1660=1 \
    -I"$src" -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$PDP10_PREFIX/include" -S "$work/unverified.c" \
    -o "$work/unverified.s" >"$work/mutant-compile.log" 2>&1
if run_guest bitmap-decode-mutant-v1660 "$work/unverified.s" \
    "$work/mutant.log"; then
    echo 'FAIL: decoder exact-consumption mutant accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant.log" || {
    tail -50 "$work/mutant.log" >&2
    exit 1
}
echo 'v1660: executed unsafe exact-consumption mutant rejected'
