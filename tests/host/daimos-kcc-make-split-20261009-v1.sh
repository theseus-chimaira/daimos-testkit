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
[ -f "$kcc/Makefile" ] && [ -f "$kcc/unix.mk" ] && [ -f "$kcc/daimos.mk" ]
(cd "$kcc" && make -n host-built > "$work/host.log")
(cd "$kcc" && make -n native-built > "$work/cross.log")
sh "$DAIMOS_REPO/scripts/stage-kcc-sources-v1.sh" \
    "$kcc" "$work/staged" "$PDP10_PREFIX/bin/csix" \
    "$PDP10_PREFIX/bin/s6text" "$DAIMOS_REPO" \
    "$PDP10_PREFIX/lib/kcc/bootstrap"
[ -s "$work/staged/MAKEFILE" ] && [ -s "$work/staged/DAIMOS.MK" ]
"$PDP10_PREFIX/bin/s6text" --decode "$work/staged/MAKEFILE" "$work/native-main.txt"
"$PDP10_PREFIX/bin/s6text" --decode "$work/staged/DAIMOS.MK" "$work/native-platform.txt"
grep -q '^PLATFORM ?= DAIMOS$' "$work/native-main.txt"
grep -q '^INCLUDE $(PLATFORM).MK$' "$work/native-main.txt"
grep -q '^> !/OPTION/BASE/EXEC/KCC ' "$work/native-platform.txt"
grep -q '^> -!/SYSTEM/EXEC/RM ' "$work/native-platform.txt"

for phase in KCPP KPARSE KGEN KOPT; do
    grep -q "^$phase: B/$phase.DXR$" "$kcc/daimos.mk"
    grep -q "^B/$phase.DXR:" "$kcc/daimos.mk"
done
python3 - "$kcc/Makefile" "$kcc/daimos.mk" <<'PY'
import pathlib, re, sys
shared = pathlib.Path(sys.argv[1]).read_text()
native = pathlib.Path(sys.argv[2]).read_text()
for name in ('KCPP', 'KPARSE', 'KGEN', 'KOPT'):
    matches = re.findall(r'^NATIVE_' + name + r'_MODULES (?:=|\+=) (.+)$', shared, re.M)
    assert matches, name
    objects = {s.rsplit('/', 1)[-1][:-2].upper() for s in matches}
    for obj in objects:
        assert 'B/' + obj + '.DOBJ:' in native, (name, obj)
        assert 'B/' + obj + '.S:' in native, (name, obj)
# Every native translation unit must rebuild when a directly or indirectly
# included local KCC header changes, including phase-specialized variants.
import re
for obj, source in re.findall(r'^(B/[A-Z0-9-]+\.S): ([A-Z0-9/-]+\.C)$', native, re.M):
    source_path = pathlib.Path(sys.argv[1]).parent / source.lower()
    if not source_path.exists():
        continue
    seen = set()
    def closure(path):
        if path in seen or not path.exists():
            return
        seen.add(path)
        for header in re.findall(r'#\s*include\s*"([^"\n]+)"', path.read_text(errors='replace')):
            for child in (path.parent / header, source_path.parent.parent / header):
                if child.exists():
                    closure(child)
                    break
    closure(source_path)
    for header in seen:
        if header.suffix == '.h':
            relative = header.relative_to(source_path.parent.parent).as_posix().upper() if source_path.parent.name == 'runtime' else header.name.upper()
            assert obj + ': ' + relative in native, (obj, relative)
# The three compiler phases also require their distinct DAIMOS runtime
# support objects, which are not part of the generic module inventories.
for phase, objects in {'KPARSE': ('DAIMOS-CHAIN', 'DAIMOS-PATH'),
                       'KGEN': ('DAIMOS-CHAIN', 'DAIMOS-PATH'),
                       'KOPT': ('DAIMOS-PATH',)}.items():
    archive = 'B/' + phase + '-RT.DARC'
    assert archive + ':' in native
    assert 'B/' + phase + '.DXR: ' + archive in native
    for obj in objects:
        assert archive + ': B/' + obj + '.DOBJ' in native
        assert 'B/' + obj + '.S: RUNTIME/' + obj + '.C' in native
assert 'include $(PLATFORM).mk' in shared
for line in (shared + native).splitlines():
    assert len(line) <= 255, line
print('KCC split Makefile / staged native graph: OK')
PY
