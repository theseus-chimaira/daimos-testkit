#!/bin/sh
# Verify native DAS -C does not silently emit a non-relocatable DXR.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS checkout}"
: "${V1404_NATIVE_DAS:?set V1404_NATIVE_DAS to native DAS build directory}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/das-native-object-gate-v1404"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
base=${V1403_ACCEPTED_WORK:-$TMPDIR/daimos-native-dlink-c89-v1403-testkit}
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1401="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
work=${V1404_WORK:-$TMPDIR/das-native-object-gate-v1404-testkit}
test -s "$base/report-v1403.md"
grep -F -- '- PASS: 5' "$base/report-v1403.md" >/dev/null
grep -F -- '- FAIL: 0' "$base/report-v1403.md" >/dev/null
for name in das das1 das2; do
    test -s "$V1404_NATIVE_DAS/$name.dxr"
    dxrcheck "$V1404_NATIVE_DAS/$name.dxr"
done
if test -e "$work"; then
    echo "v1404: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work"
echo 'V1404 PHASE 1: grouped D6FS with new native DAS phases'
export V1372_NORMAL_BUILD="$TMPDIR/d6codec-fulldist-v1371/normal-build"
python3 -B "$testkit/tests/validation/daimos-native-dlink-c89-v1403/build_root_v1403.py" \
    "$daimos" "$testkit" "$work" "$v1401/native" \
    "$V1404_NATIVE_DAS" "$base/objects" \
    > "$work/root-build-v1404.log" 2>&1 || {
        tail -60 "$work/root-build-v1404.log" >&2
        exit 1
    }
python3 - "$base/boot-v1403.simh" "$work/boot-v1404.simh" \
    "$base/disk-pristine-v1403" "$work/disk-pristine-v1403" <<'PY'
from pathlib import Path
import sys
original, output, old, new = sys.argv[1:]
data = Path(original).read_text()
if data.count(old) != 4:
    raise SystemExit('v1404: unexpected media reference count')
Path(output).write_text(data.replace(old, new))
PY
echo 'V1404 PHASE 2: guest direct DXR and negative object gate'
sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1404.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1404.txt" --isolate-media \
    --work-dir "$work/native-run-v1404" \
    --markdown-report "$work/report-v1404.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1404.log" 2>&1 || {
        tail -60 "$work/guest-v1404.log" >&2
        exit 1
    }
cat "$work/guest-v1404.log"
test "$(grep -c '^PASS' "$work/native-run-v1404/results.tsv")" -eq 4
grep -F -- '- FAIL: 0' "$work/report-v1404.md" >/dev/null
echo 'PASS v1404: direct DXR preserved; -C rejects unsupported DOBJ'
