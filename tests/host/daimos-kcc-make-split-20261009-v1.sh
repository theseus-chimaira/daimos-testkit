#!/bin/sh
# Verify the shared KCC inventory and the staged native MAKE fragments.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
kcc=${KCC_REPO:-"$DAIMOS_REPO/../kcc"}
work=$(mktemp -d "$TMPDIR/kcc-make-split-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

[ ! -e "$DAIMOS_REPO/scripts/gen-kcc-native-make-v1.py" ]
[ -f "$kcc/Makefile" ] && [ -f "$kcc/native.mk" ] && [ -f "$kcc/daimos.mk" ]
(cd "$kcc" && make -n cross > "$work/host.log")
(cd "$kcc" && make -n native > "$work/cross.log")
sh "$DAIMOS_REPO/scripts/stage-kcc-sources-v1.sh" \
    "$kcc" "$work/staged" "$PDP10_PREFIX/bin/csix" \
    "$PDP10_PREFIX/bin/s6text" "$DAIMOS_REPO" \
    "$PDP10_PREFIX/lib/kcc/bootstrap"
[ -s "$work/staged/MAKEFILE" ] && [ -s "$work/staged/DAIMOS.MK" ]
"$PDP10_PREFIX/bin/s6text" --decode "$work/staged/MAKEFILE" "$work/native-main.txt"
"$PDP10_PREFIX/bin/s6text" --decode "$work/staged/DAIMOS.MK" "$work/native-platform.txt"
grep -q '^PLATFORM ?= DAIMOS$' "$work/native-main.txt"
grep -q '^INCLUDE $(PLATFORM).MK$' "$work/native-main.txt"
grep -q '^> !$(NATIVE_KCC) ' "$work/native-platform.txt"
grep -q '^> !$(NATIVE_DAS) ' "$work/native-platform.txt"

for phase in KCPP KPARSE KGEN KOPT; do
    grep -q "^BUILD/$phase.DXR:" "$kcc/daimos.mk"
    grep -q "^BUILD/$phase.DXR:" "$kcc/daimos.mk"
done
python3 - "$kcc/Makefile" "$kcc/daimos.mk" <<'PY_CHECK'
import pathlib, re, sys
shared = pathlib.Path(sys.argv[1]).read_text()
native = pathlib.Path(sys.argv[2]).read_text()
assert 'include $(PLATFORM).mk' in shared
assert 'BUILD/KCPP.DXR:' in native
for phase in ('KCPP', 'KPARSE', 'KGEN', 'KOPT'):
    assert re.search(r'^BUILD/' + phase + r'\.DXR:', native, re.M), phase
    assert 'BUILD/' + phase + '.DXR:' in native
for phase in ('KPARSE', 'KGEN', 'KOPT'):
    archive = 'BUILD/' + phase + '-RT.DARC'
    assert archive + ':' in native
    assert archive in native.split('BUILD/' + phase + '.DXR:', 1)[1].split('\nBUILD/', 1)[0]
for obj, source in re.findall(r'^(BUILD/[A-Z0-9-]+\.S): BUILD ([A-Z0-9/-]+\.C)', native, re.M):
    assert (pathlib.Path(sys.argv[1]).parent / source.lower()).is_file(), (obj, source)
assert len(re.findall(r'^BUILD/[A-Z0-9-]+\.S:', native, re.M)) >= 20
for line in native.splitlines():
    assert len(line) <= 255, line
print('KCC native staged graph: PASS')
PY_CHECK
