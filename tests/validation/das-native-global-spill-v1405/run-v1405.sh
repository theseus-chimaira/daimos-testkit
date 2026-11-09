#!/bin/sh
# Verify global DOBJ1 IDs survive the native DASIR2 phase boundary.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS checkout}"
: "${V1405_NATIVE_DAS:?set V1405_NATIVE_DAS to rebuilt native DAS directory}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/das-native-global-spill-v1405"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
base=${V1403_ACCEPTED_WORK:-$TMPDIR/daimos-native-dlink-c89-v1403-testkit}
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1401="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
work=${V1405_WORK:-$TMPDIR/das-native-global-spill-v1405-testkit}

test -s "$base/report-v1403.md"
grep -F -- '- PASS: 5' "$base/report-v1403.md" >/dev/null
grep -F -- '- FAIL: 0' "$base/report-v1403.md" >/dev/null
for name in das das1 das2; do
    test -s "$V1405_NATIVE_DAS/$name.dxr"
    dxrcheck "$V1405_NATIVE_DAS/$name.dxr"
done
if test -e "$work"; then
    echo "v1405: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work"
python3 -B "$here/make_fixture_v1405.py" \
    "$work/metadata-v1405.a7"
V1405_OBJECT_METADATA_A7="$work/metadata-v1405.a7"
export V1405_OBJECT_METADATA_A7
export V1372_NORMAL_BUILD="$TMPDIR/d6codec-fulldist-v1371/normal-build"

echo 'V1405 PHASE 1: full grouped root with spill-backed DAS1/DAS2'
python3 -B \
    "$testkit/tests/validation/daimos-native-dlink-c89-v1403/build_root_v1403.py" \
    "$daimos" "$testkit" "$work" "$v1401/native" \
    "$V1405_NATIVE_DAS" "$base/objects" \
    > "$work/root-build-v1405.log" 2>&1 || {
        tail -60 "$work/root-build-v1405.log" >&2
        exit 1
    }
grep -F V1403_ROOT_PASS "$work/root-build-v1405.log" >/dev/null
python3 - "$base/boot-v1403.simh" "$work/boot-v1405.simh" \
    "$base/disk-pristine-v1403" "$work/disk-pristine-v1403" <<'PY'
from pathlib import Path
import sys
original, output, old, new = sys.argv[1:]
data = Path(original).read_text()
if data.count(old) != 4:
    raise SystemExit('v1405: incorrect boot-media reference count')
Path(output).write_text(data.replace(old, new))
PY

echo 'V1405 PHASE 2: guest compiler and native DASIR2 metadata gates'
sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1405.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1405.txt" --isolate-media \
    --work-dir "$work/native-run-v1405" \
    --markdown-report "$work/report-v1405.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1405.log" 2>&1 || {
        tail -60 "$work/guest-v1405.log" >&2
        exit 1
    }
cat "$work/guest-v1405.log"
test "$(grep -c '^PASS' "$work/native-run-v1405/results.tsv")" -eq 5
grep -F -- '- FAIL: 0' "$work/report-v1405.md" >/dev/null
echo 'PASS v1405: spill-backed global indices survive native DASIR2'
