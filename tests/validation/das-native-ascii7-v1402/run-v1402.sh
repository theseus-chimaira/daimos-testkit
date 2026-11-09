#!/bin/sh
# Build and boot an isolated grouped DAIMOS root with native DAS ASCII7.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS checkout}"
: "${DAS_REPO:?set DAS_REPO to staged DAS -A source checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH

testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/das-native-ascii7-v1402"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
das=$(CDPATH= cd -- "$DAS_REPO" && pwd -P)
base="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
v1373="$TMPDIR/kcc-native-refresh-v1373"
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
work=${V1402_WORK:-$TMPDIR/das-native-ascii7-v1402-testkit}

test -s "$base/report-v1401.md"
grep -F -- '- PASS: 16' "$base/report-v1401.md" >/dev/null
grep -F -- '- FAIL: 0' "$base/report-v1401.md" >/dev/null
test -s "$base/boot-v1401.simh"
test -s "$v1371/normal-build/external/das/das.dxr"
test -x "$v1370/pty-run-v1370"
test -s "$v1373/fixture-host-v1373.s"
test -s "$v1373/fixture-host-v1373.a7"

if test -e "$work"; then
    echo "v1402: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work" "$work/das-source" "$work/native-das"

echo 'V1402 PHASE 1: isolated native DAS source build'
# The normal DAS Makefile builds the host assembler in its source tree.
# Copy the exact staged source into test storage so nothing is written
# into either the source checkout or the installed toolchain.
cp "$das"/*.c "$das"/*.h "$das/Makefile" "$das/DAS.SIXMD" \
    "$work/das-source/"
if ! make -j2 -C "$work/das-source" \
    "NATIVE_BUILD_DIR=$work/native-das" \
    "DAIMOS_REPO=$daimos" "PDP10_PREFIX=$PDP10_PREFIX" \
    "PDP10_KCC=$base/host/kcc" \
    "PDP10_DLINK=$PDP10_PREFIX/bin/dlink" \
    "NATIVE_DAS=$PDP10_PREFIX/bin/das" \
    "SIXMD_CHECK=$PDP10_PREFIX/bin/sixmd-check" native \
    > "$work/native-build-v1402.log" 2>&1; then
    tail -75 "$work/native-build-v1402.log" >&2
    exit 1
fi
for name in das das1 das2; do
    dxrcheck "$work/native-das/$name.dxr"
done

echo 'V1402 PHASE 2: independent host-assembled ASCII7/S6REC fixtures'
python3 -B "$here/make_fixtures_v1402.py" \
    "$PDP10_PREFIX/bin/das" "$PDP10_PREFIX/bin/s6text" \
    "$v1373/fixture-host-v1373.s" "$work/fixtures" \
    "$v1373/fixture-host-v1373.a7"

echo 'V1402 PHASE 3: build a complete clean grouped D6FS test root'
export V1372_NORMAL_BUILD="$v1371/normal-build"
if ! python3 -B "$here/build_root_v1402.py" \
    "$daimos" "$testkit" "$work" "$base/native" \
    "$work/native-das" "$work/fixtures" \
    > "$work/root-build-v1402.log" 2>&1; then
    tail -70 "$work/root-build-v1402.log" >&2
    exit 1
fi
grep -F V1402_ROOT_PASS "$work/root-build-v1402.log" >/dev/null
python3 - "$base/boot-v1401.simh" "$work/boot-v1402.simh" \
    "$base/disk-pristine-v1373" "$work/disk-pristine-v1402" <<'PY'
from pathlib import Path
import sys
source, dest, previous, replacement = sys.argv[1:]
content = Path(source).read_text()
if content.count(previous) != 4:
    raise SystemExit('v1402: expected exactly four clean disk references')
Path(dest).write_text(content.replace(previous, replacement))
PY

echo 'V1402 PHASE 4: native PDP-6 DAS positive/negative guest acceptance'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1402.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1402.txt" --isolate-media \
    --work-dir "$work/native-run-v1402" \
    --markdown-report "$work/report-v1402.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1402.log" 2>&1; then
    tail -70 "$work/guest-v1402.log" >&2
    exit 1
fi
cat "$work/guest-v1402.log"
if grep '^FAIL' "$work/native-run-v1402/results.tsv" >/dev/null; then
    echo 'v1402: native DAS ASCII7 regression failed' >&2
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-run-v1402/results.tsv")" -eq 17
grep -F -- '- FAIL: 0' "$work/report-v1402.md" >/dev/null
echo 'PASS v1402: 17 native DAS ASCII7/S6REC, quoted-data and RUN tests'
