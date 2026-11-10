#!/bin/sh
# Validate native DLINK using independently built host DOBJ1 input.
# This does not claim native DAS -C output works.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${V1403_DAS_NATIVE:?set V1403_DAS_NATIVE to accepted v1402 native binaries}"
: "${V1403_KCC_NATIVE:?set V1403_KCC_NATIVE to accepted v1401 native binaries}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH

testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/native-dlink-c-v1403"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
base="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
prior="$TMPDIR/das-native-ascii7-v1402-testkit-r2"
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
work=${V1403_WORK:-$TMPDIR/native-dobj-link-v1403-testkit}

test -s "$base/report-v1401.md"
grep -F -- '- PASS: 16' "$base/report-v1401.md" >/dev/null
test -s "$prior/report-v1402.md"
grep -F -- '- PASS: 17' "$prior/report-v1402.md" >/dev/null
grep -F -- '- FAIL: 0' "$prior/report-v1402.md" >/dev/null
test -x "$v1370/pty-run-v1370"
test -s "$prior/boot-v1402.simh"
test -s "$v1371/normal-build/external/das/das.dxr"
test -x "$base/host/kcc"
if test -e "$work"; then
    echo "v1403: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work"

echo 'V1403 PHASE 1: host C89 source and DOBJ/DXR golden fixtures'
python3 -B "$here/make_fixtures_v1403.py" \
    "$base/host/kcc" "$PDP10_PREFIX/bin/das" \
    "$PDP10_PREFIX/bin/dlink" "$PDP10_PREFIX/bin/csix" \
    "$here/native-main-v1403.c" "$work/fixtures" \
    "$v1370/userland-build/userland/d6lz/libc"
dxrcheck "$work/fixtures/native-gold-v1403.dxr"

echo 'V1403 PHASE 2: isolated full grouped root with host DOBJ fixtures'
export V1372_NORMAL_BUILD="$v1371/normal-build"
if ! python3 -B "$here/build_root_v1403.py" \
    "$daimos" "$testkit" "$work" \
    "$V1403_KCC_NATIVE" "$V1403_DAS_NATIVE" "$work/fixtures" \
    > "$work/root-build-v1403.log" 2>&1; then
    tail -65 "$work/root-build-v1403.log" >&2
    exit 1
fi
grep -F V1403_ROOT_PASS "$work/root-build-v1403.log" >/dev/null
python3 - "$prior/boot-v1402.simh" "$work/boot-v1403.simh" \
    "$prior/disk-pristine-v1402" "$work/disk-pristine-v1403" <<'PY'
from pathlib import Path
import sys
source, dest, old, new = sys.argv[1:]
text = Path(source).read_text()
if text.count(old) != 4:
    raise SystemExit('v1403: unexpected grouped disk references')
Path(dest).write_text(text.replace(old, new))
PY

echo 'V1403 PHASE 3: real native PDP-6 C89/link/RUN probes'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1403.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1403.txt" --isolate-media \
    --work-dir "$work/native-run-v1403" \
    --markdown-report "$work/report-v1403.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1403.log" 2>&1; then
    tail -80 "$work/guest-v1403.log" >&2
    exit 1
fi
cat "$work/guest-v1403.log"
if grep '^FAIL' "$work/native-run-v1403/results.tsv" >/dev/null; then
    echo 'v1403: native compiler/linker host-DOBJ regression failed' >&2
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-run-v1403/results.tsv")" -eq 5
grep -F -- '- FAIL: 0' "$work/report-v1403.md" >/dev/null
echo 'PASS v1403: native KCC C89 identity and native DLINK/exec with host DOBJ'
