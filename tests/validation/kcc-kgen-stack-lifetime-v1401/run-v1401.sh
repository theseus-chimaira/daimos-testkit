#!/bin/sh
# Rebuild the corrected native KCC phases and test KIR1/KPCODE2 on PDP-6.
# Requires an accepted v1373/v1371 isolated grouped distribution baseline.
# Never installs native tools or changes production disk images.
set -eu

: "${DAIMOS_REPO:?set DAIMOS_REPO to the staged DAIMOS checkout}"
: "${KCC_REPO:?set KCC_REPO to the staged corrected KCC checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH

testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/kcc-kgen-stack-lifetime-v1401"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
kcc=$(CDPATH= cd -- "$KCC_REPO" && pwd -P)
base="$TMPDIR/kcc-native-refresh-v1373"
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
work=${V1401_WORK:-$TMPDIR/kcc-kgen-stack-lifetime-v1401}

# A complete prerequisite run produces the bootloader, uncompressed
# distribution objects, exact host reference and the C89 fixture DXR.
test -s "$base/report-v1373.md" || {
    echo 'v1401: run kcc-native-refresh-v1373 first' >&2
    exit 2
}
grep -F -- '- FAIL: 0' "$base/report-v1373.md" >/dev/null
test -s "$base/boot-v1373.simh"
test -x "$v1370/pty-run-v1370"
test -s "$v1371/normal-build/external/das/das.dxr"
for fixture in fixture-v1373.s6 fixture-host-v1373.a7 \
    nested-v1373.s6 nested-host-v1373.a7 nested-v1373.dxr; do
    test -s "$base/$fixture"
done

if test -e "$work"; then
    echo "v1401: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work" "$work/host" "$work/native"
host="$work/host/kcc"
native="$work/native"

echo 'V1401 PHASE 1: rebuild the corrected host compiler'
if ! make -j2 -C "$kcc" \
    "HOST_BUILD_DIR=$work/host" "KCC=$host" "$host" \
    > "$work/host-build.log" 2>&1; then
    tail -60 "$work/host-build.log" >&2
    exit 1
fi

echo 'V1401 PHASE 2: rebuild all five native compiler images'
if ! make -j2 -C "$kcc" \
    "NATIVE_BUILD_DIR=$native" \
    "NATIVE_DAIMOS_LIBC_ROOT=$native/daimos-libc" \
    "DAIMOS_REPO=$daimos" "PDP10_PREFIX=$PDP10_PREFIX" \
    "KCC=$host" \
    "$native/KCC.dxr" "$native/KCPP.dxr" \
    "$native/KPARSE.dxr" "$native/KGEN.dxr" "$native/KOPT.dxr" \
    > "$work/native-build.log" 2>&1; then
    tail -70 "$work/native-build.log" >&2
    exit 1
fi
for name in KCC KCPP KPARSE KGEN KOPT; do
    dxrcheck "$native/$name.dxr"
done

echo 'V1401 PHASE 3: build a full isolated 237-file grouped D6FS root'
export V1372_NORMAL_BUILD="$v1371/normal-build"
if ! python3 -B \
    "$testkit/tests/validation/kcc-native-refresh-v1373/build_root_v1373.py" \
    "$daimos" "$testkit" "$work" "$native" \
    "$base/fixture-v1373.s6" "$base/fixture-host-v1373.a7" \
    "$base/nested-v1373.s6" "$base/nested-host-v1373.a7" \
    "$base/nested-v1373.dxr" \
    > "$work/root-build.log" 2>&1; then
    tail -70 "$work/root-build.log" >&2
    exit 1
fi
grep -F V1373_D6FS_CLEAN_PASS "$work/root-build.log" >/dev/null
python3 - "$base/boot-v1373.simh" "$work/boot-v1401.simh" \
    "$base/disk-pristine-v1373" "$work/disk-pristine-v1373" <<'PY'
from pathlib import Path
import sys
source, dest, previous, replacement = sys.argv[1:]
config = Path(source).read_text()
if config.count(previous) != 4:
    raise SystemExit('v1401: unexpected boot image disk paths')
Path(dest).write_text(config.replace(previous, replacement))
PY

echo 'V1401 PHASE 4: strict optimized/-N compiler and replay acceptance'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1401.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1401.txt" --isolate-media \
    --work-dir "$work/native-run-v1401" \
    --markdown-report "$work/report-v1401.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1401.log" 2>&1; then
    tail -80 "$work/guest-v1401.log" >&2
    exit 1
fi
cat "$work/guest-v1401.log"
if grep '^FAIL' "$work/native-run-v1401/results.tsv" >/dev/null; then
    echo 'v1401: a required native compiler exit-status gate failed' >&2
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-run-v1401/results.tsv")" -eq 16
grep -F -- '- FAIL: 0' "$work/report-v1401.md" >/dev/null
echo 'PASS v1401: 16 strict native KCC/KIR1/KGEN(-N)/KOPT/host-equality checks'
