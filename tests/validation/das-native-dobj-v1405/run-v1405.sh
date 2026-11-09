#!/bin/sh
# Full guest compiler -> native object assembler -> native linker -> RUN.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${NATIVE_DAS_BUILD:?set NATIVE_DAS_BUILD to staged v1405 DAS outputs}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH

testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/das-native-dobj-v1405"
probes=${V1405_PROBES:-$here/probes-v1405.txt}
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
native_das=$(CDPATH= cd -- "$NATIVE_DAS_BUILD" && pwd -P)
v1401="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
v1403="$TMPDIR/daimos-native-dlink-c89-v1403-testkit"
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
work=${V1405_WORK:-$TMPDIR/das-native-dobj-v1405-testkit}

test -s "$v1403/report-v1403.md"
grep -F -- '- PASS: 5' "$v1403/report-v1403.md" >/dev/null
grep -F -- '- FAIL: 0' "$v1403/report-v1403.md" >/dev/null
for prog in das das1 das2; do
    dxrcheck "$native_das/$prog.dxr"
done
test ! -e "$work" || {
    echo "v1405: refusing to overwrite existing $work" >&2
    exit 2
}
mkdir -p "$work"
if test -z "${V1405_PROBES:-}"; then
    probes="$work/probes-extended-v1405.txt"
    python3 -B "$here/make_probes_v1405.py" "$probes"
else
    probes=$V1405_PROBES
fi
export V1372_NORMAL_BUILD="$v1371/normal-build"

echo 'V1405 PHASE 1: stage full grouped root with experimental native DAS'
if ! python3 -B "$here/make_fixtures_v1405.py" \
    "$here" "$work/fixtures" "$v1401/host/kcc" \
    "$PDP10_PREFIX/bin/das" "$PDP10_PREFIX/bin/dlink" \
    "$PDP10_PREFIX/bin/csix" \
    "$v1370/userland-build/userland/d6lz/libc/crt0.dobj" \
    > "$work/fixtures.log" 2>&1; then
    tail -65 "$work/fixtures.log" >&2
    exit 1
fi
if ! python3 -B "$here/build_root_v1405.py" \
    "$daimos" "$testkit" "$work" "$v1401/native" \
    "$native_das" "$v1403/objects" "$work/fixtures" \
    > "$work/root.log" 2>&1; then
    tail -70 "$work/root.log" >&2
    exit 1
fi
grep -F V1405_ROOT_PASS "$work/root.log" >/dev/null
python3 - "$v1401/boot-v1401.simh" "$work/boot-v1405.simh" \
    "$v1401/disk-pristine-v1373" "$work/disk-pristine-v1405" <<'PY'
from pathlib import Path
import sys
source, output, old, new = sys.argv[1:]
config = Path(source).read_text()
if config.count(old) != 4:
    raise SystemExit('incorrect image path reference count')
Path(output).write_text(config.replace(old, new))
PY

echo 'V1405 PHASE 2: native DAS -A -C and DLINK execution'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1405.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$probes" --isolate-media \
    --work-dir "$work/native-run-v1405" \
    --markdown-report "$work/report-v1405.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1405.log" 2>&1; then
    tail -80 "$work/guest-v1405.log" >&2
    exit 1
fi
cat "$work/guest-v1405.log"
if grep '^FAIL' "$work/native-run-v1405/results.tsv" >/dev/null; then
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-run-v1405/results.tsv")" -eq \
    "$(grep -c '^probe ' "$probes")"
grep -F -- '- FAIL: 0' "$work/report-v1405.md" >/dev/null
echo "PASS v1405: $(grep -c '^probe ' "$probes") strict guest probes from $probes"
