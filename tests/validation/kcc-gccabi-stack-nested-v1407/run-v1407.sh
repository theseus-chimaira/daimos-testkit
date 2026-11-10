#!/bin/sh
# Verify the nested-register-call/outgoing-stack-argument ABI fix on PDP-6.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS checkout}"
: "${KCC_REPO:?set KCC_REPO to the corrected staged KCC checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH

testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/kcc-gccabi-stack-nested-v1407"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
kcc=$(CDPATH= cd -- "$KCC_REPO" && pwd -P)
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
v1401="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
v1402=${V1402_ACCEPTED_WORK:-$TMPDIR/das-native-ascii7-v1402-testkit-r2}
v1403=${V1403_ACCEPTED_WORK:-$TMPDIR/daimos-native-dlink-c89-v1403-testkit}
work=${V1407_WORK:-$TMPDIR/kcc-gccabi-stack-nested-v1407-testkit}

test -s "$v1403/report-v1403.md"
grep -F -- '- PASS: 5' "$v1403/report-v1403.md" >/dev/null
grep -F -- '- FAIL: 0' "$v1403/report-v1403.md" >/dev/null
test -x "$v1401/host/kcc"
test -s "$v1401/native/KCC.dxr"
test -s "$v1402/native-das/das.dxr"
test -s "$v1371/normal-build/external/das/das.dxr"
test -x "$v1370/pty-run-v1370"

if test -e "$work"; then
    echo "v1407: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work/host" "$work/objects"

echo 'V1407 PHASE 1: compile the corrected KCC host driver from source'
if ! make -j2 -C "$kcc" "HOST_BUILD_DIR=$work/host" \
    "KCC=$work/host/kcc" "$work/host/kcc" \
    > "$work/host-build-v1407.log" 2>&1; then
    tail -75 "$work/host-build-v1407.log" >&2
    exit 1
fi

echo 'V1407 PHASE 2: independent old/new C89 objects and DXRs'
for mode in old new; do
    if test "$mode" = old; then
        compiler="$v1401/host/kcc"
    else
        compiler="$work/host/kcc"
    fi
    if ! "$compiler" -Pgnu99 -O -x=pdp6 -m=gas -S \
        "$here/nested-stack-v1407.c" \
        -o "$work/objects/$mode-v1407.s" \
        > "$work/$mode-compile-v1407.log" 2>&1; then
        tail -60 "$work/$mode-compile-v1407.log" >&2
        exit 1
    fi
    das -F -C -O "$work/objects/$mode-v1407.dobj" \
        "$work/objects/$mode-v1407.s"
    dlink -b 020 -o "$work/objects/$mode-v1407.dxr" \
        "$v1370/userland-build/userland/d6lz/libc/crt0.dobj" \
        "$work/objects/$mode-v1407.dobj" \
        "$v1370/userland-build/userland/d6lz/libc/syscall.dobj"
    dxrcheck "$work/objects/$mode-v1407.dxr"
done

# A second code-generation path exercises the fix without -O.
if ! "$work/host/kcc" -Pgnu99 -n -x=pdp6 -m=gas -S \
    "$here/nested-stack-v1407.c" \
    -o "$work/objects/noopt-v1410.s" \
    > "$work/noopt-compile-v1410.log" 2>&1; then
    tail -60 "$work/noopt-compile-v1410.log" >&2
    exit 1
fi
das -F -C -O "$work/objects/noopt-v1410.dobj" \
    "$work/objects/noopt-v1410.s"
dlink -b 020 -o "$work/objects/noopt-v1410.dxr" \
    "$v1370/userland-build/userland/d6lz/libc/crt0.dobj" \
    "$work/objects/noopt-v1410.dobj" \
    "$v1370/userland-build/userland/d6lz/libc/syscall.dobj"
dxrcheck "$work/objects/noopt-v1410.dxr"
if cmp -s "$work/objects/noopt-v1410.s" \
          "$work/objects/new-v1407.s"; then
    echo 'v1410: -n unexpectedly produced optimized assembly' >&2
    exit 1
fi
if cmp -s "$work/objects/old-v1407.s" \
          "$work/objects/new-v1407.s"; then
    echo 'v1407: source fix produced no code generation change' >&2
    exit 1
fi

echo 'V1407 PHASE 3: full isolated grouped root with both linked DXRs'
export V1372_NORMAL_BUILD="$v1371/normal-build"
V1407_BEFORE_DXR="$work/objects/old-v1407.dxr"
V1407_AFTER_DXR="$work/objects/new-v1407.dxr"
V1410_NOOPT_DXR="$work/objects/noopt-v1410.dxr"
export V1407_BEFORE_DXR V1407_AFTER_DXR V1410_NOOPT_DXR
if ! python3 -B \
    "$testkit/tests/validation/daimos-native-dlink-c89-v1403/build_root_v1403.py" \
    "$daimos" "$testkit" "$work" "$v1401/native" \
    "$v1402/native-das" "$v1403/objects" \
    > "$work/root-build-v1407.log" 2>&1; then
    tail -65 "$work/root-build-v1407.log" >&2
    exit 1
fi
grep -F V1403_ROOT_PASS "$work/root-build-v1407.log" >/dev/null
python3 - "$v1403/boot-v1403.simh" "$work/boot-v1407.simh" \
    "$v1403/disk-pristine-v1403" "$work/disk-pristine-v1403" <<'PY'
from pathlib import Path
import sys
original, output, previous, current = sys.argv[1:]
source = Path(original).read_text()
if source.count(previous) != 4:
    raise SystemExit('v1407: expected four boot-media paths')
Path(output).write_text(source.replace(previous, current))
PY

echo 'V1407 PHASE 4: PDP-6 before/after execution'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1407.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1407.txt" --isolate-media \
    --work-dir "$work/native-run-v1407" \
    --markdown-report "$work/report-v1407.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1407.log" 2>&1; then
    tail -75 "$work/guest-v1407.log" >&2
    exit 1
fi
cat "$work/guest-v1407.log"
if grep '^FAIL' "$work/native-run-v1407/results.tsv" >/dev/null; then
    echo 'v1407: native ABI regression failed' >&2
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-run-v1407/results.tsv")" -eq 3
grep -F -- '- FAIL: 0' "$work/report-v1407.md" >/dev/null
echo 'PASS v1410: corrected KCC preserves nested outgoing stack args with and without -O'
