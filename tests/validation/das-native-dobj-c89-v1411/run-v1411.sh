#!/bin/sh
# Native KCC -> DAS -A -C -> DLINK -> RUN: no host-generated main object.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS checkout}"
: "${V1411_NATIVE_DAS:?set V1411_NATIVE_DAS to native DAS build directory}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/das-native-dobj-c89-v1411"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
base=${V1403_ACCEPTED_WORK:-$TMPDIR/daimos-native-dlink-c89-v1403-testkit}
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1401=${V1411_NATIVE_KCC:-$TMPDIR/kcc-kgen-stack-lifetime-v1409b-regression/native}
host_kcc=${V1411_HOST_KCC:-$TMPDIR/kcc-gccabi-stack-v1409b/host/kcc}
work=${V1411_WORK:-$TMPDIR/das-native-dobj-c89-v1411-testkit}

test -s "$base/report-v1403.md"
grep -F -- '- PASS: 5' "$base/report-v1403.md" >/dev/null
grep -F -- '- FAIL: 0' "$base/report-v1403.md" >/dev/null
test -x "$host_kcc"
for name in das das1 das2; do
    test -s "$V1411_NATIVE_DAS/$name.dxr"
    dxrcheck "$V1411_NATIVE_DAS/$name.dxr"
done
for name in KCC KCPP KPARSE KGEN KOPT; do
    test -s "$v1401/$name.dxr"
done
if test -e "$work"; then
    echo "v1411: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work/objects"

echo 'V1411 PHASE 1: independent host KCC and host DAS DOBJ1 reference'
"$host_kcc" -Pgnu99 -O -x=pdp6 -m=gas -S \
    "$base/objects/main-v1403.c" -o "$work/objects/host-v1411.s" \
    > "$work/host-kcc-v1411.log" 2>&1 || {
        tail -60 "$work/host-kcc-v1411.log" >&2
        exit 1
    }
das -C -O "$work/objects/host-v1411.dobj" \
    "$work/objects/host-v1411.s"
cp "$base/objects/crt0.dobj" "$work/objects/crt0.dobj"
cp "$base/objects/syscall.dobj" "$work/objects/syscall.dobj"
cp "$base/objects/main-v1403.s6rec" "$work/objects/main-v1403.s6rec"
cp "$base/objects/host-v1403.dxr" "$work/objects/host-v1403.dxr"
cp "$base/objects/main.dobj" "$work/objects/main.dobj"
V1411_HOST_DOBJ="$work/objects/host-v1411.dobj"
export V1411_HOST_DOBJ

echo 'V1411 PHASE 2: clean grouped D6FS root with native object writer'
export V1372_NORMAL_BUILD="$TMPDIR/d6codec-fulldist-v1371/normal-build"
python3 -B \
    "$testkit/tests/validation/daimos-native-dlink-c89-v1403/build_root_v1403.py" \
    "$daimos" "$testkit" "$work" "$v1401" \
    "$V1411_NATIVE_DAS" "$work/objects" \
    > "$work/root-build-v1411.log" 2>&1 || {
        tail -70 "$work/root-build-v1411.log" >&2
        exit 1
    }
grep -F V1403_ROOT_PASS "$work/root-build-v1411.log" >/dev/null
python3 - "$base/boot-v1403.simh" "$work/boot-v1411.simh" \
    "$base/disk-pristine-v1403" "$work/disk-pristine-v1403" <<'PY'
from pathlib import Path
import sys
original, output, old, new = sys.argv[1:]
data = Path(original).read_text()
if data.count(old) != 4:
    raise SystemExit('v1411: unexpected boot-media reference count')
Path(output).write_text(data.replace(old, new))
PY

echo 'V1411 PHASE 3: native KCC, native DOBJ1, native DLINK and RUN'
sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1411.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1411.txt" --isolate-media \
    --work-dir "$work/native-run-v1411" \
    --markdown-report "$work/report-v1411.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1411.log" 2>&1 || {
        tail -70 "$work/guest-v1411.log" >&2
        exit 1
    }
cat "$work/guest-v1411.log"
test "$(grep -c '^PASS' "$work/native-run-v1411/results.tsv")" -eq 5
grep -F -- '- FAIL: 0' "$work/report-v1411.md" >/dev/null
echo 'PASS v1411: native-compiled C89 DOBJ matches host and runs under DLINK'
