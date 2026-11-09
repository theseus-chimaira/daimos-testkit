#!/bin/sh
# Isolate native DLINK correctness from unfinished native DAS -C support.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH

testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/daimos-native-dlink-c89-v1403"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
v1401="$TMPDIR/kcc-kgen-stack-lifetime-v1401-testkit"
v1402=${V1402_ACCEPTED_WORK:-$TMPDIR/das-native-ascii7-v1402-testkit-r2}
work=${V1403_WORK:-$TMPDIR/daimos-native-dlink-c89-v1403-testkit}

test -x "$v1401/host/kcc"
test -s "$v1401/native/KCC.dxr"
test -s "$v1402/native-das/das.dxr"
test -s "$v1402/report-v1402.md"
grep -F -- '- PASS: 17' "$v1402/report-v1402.md" >/dev/null
grep -F -- '- FAIL: 0' "$v1402/report-v1402.md" >/dev/null
test -s "$v1371/normal-build/external/das/das.dxr"
test -x "$v1370/pty-run-v1370"

if test -e "$work"; then
    echo "v1403: refusing to overwrite existing $work" >&2
    exit 2
fi
mkdir -p "$work/objects"

echo 'V1403 PHASE 1: independently compile C89 to DOBJ1 with host tools'
cp "$here/main-v1403.c" "$work/objects/main-v1403.c"
csix -e "$here/main-v1403.c" "$work/objects/main-v1403.s6rec"
if ! "$v1401/host/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -S "$here/main-v1403.c" -o "$work/objects/main-v1403.s" \
    > "$work/host-kcc-v1403.log" 2>&1; then
    tail -60 "$work/host-kcc-v1403.log" >&2
    exit 1
fi
das -F -C -O "$work/objects/main.dobj" \
    "$work/objects/main-v1403.s"
native_lib="$v1370/userland-build/userland/d6lz/libc"
cp "$native_lib/crt0.dobj" "$work/objects/crt0.dobj"
cp "$native_lib/syscall.dobj" "$work/objects/syscall.dobj"
dlink -b 020 -o "$work/objects/host-v1403.dxr" \
    "$work/objects/crt0.dobj" "$work/objects/main.dobj" \
    "$work/objects/syscall.dobj"
dxrcheck "$work/objects/host-v1403.dxr"

echo 'V1403 PHASE 2: full grouped D6FS root with host object inputs'
export V1372_NORMAL_BUILD="$v1371/normal-build"
if ! python3 -B "$here/build_root_v1403.py" \
    "$daimos" "$testkit" "$work" "$v1401/native" \
    "$v1402/native-das" "$work/objects" \
    > "$work/root-build-v1403.log" 2>&1; then
    tail -70 "$work/root-build-v1403.log" >&2
    exit 1
fi
grep -F V1403_ROOT_PASS "$work/root-build-v1403.log" >/dev/null

python3 - "$v1401/boot-v1401.simh" "$work/boot-v1403.simh" \
    "$v1401/disk-pristine-v1373" "$work/disk-pristine-v1403" <<'PY'
from pathlib import Path
import sys
original, output, previous, new = sys.argv[1:]
data = Path(original).read_text()
if data.count(previous) != 4:
    raise SystemExit('v1403: unexpected boot media reference count')
Path(output).write_text(data.replace(previous, new))
PY

echo 'V1403 PHASE 3: guest KCC/DAS, native DLINK and C89 RUN'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1403.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$here/probes-v1403.txt" --isolate-media \
    --work-dir "$work/native-run-v1403" \
    --markdown-report "$work/report-v1403.md" \
    --boot-timeout 115 --timeout 320 \
    > "$work/guest-v1403.log" 2>&1; then
    tail -70 "$work/guest-v1403.log" >&2
    exit 1
fi
cat "$work/guest-v1403.log"
if grep '^FAIL' "$work/native-run-v1403/results.tsv" >/dev/null; then
    echo 'v1403: native toolchain linkage check failed' >&2
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-run-v1403/results.tsv")" -eq 5
grep -F -- '- FAIL: 0' "$work/report-v1403.md" >/dev/null
echo 'PASS v1403: native DLINK links host DOBJ1 and executes C89 return 7'
