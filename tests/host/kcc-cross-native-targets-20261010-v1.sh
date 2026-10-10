#!/bin/sh
# Validate public build targets without running any compiler or build recipe.
set -eu
: "${KCC_REPO:?}" "${BMAKE:?}" "${MAKESYSPATH:?}"
cd "$KCC_REPO"
for makecmd in gmake "$BMAKE"; do
    "$makecmd" -n -f Makefile > "$TMPDIR/kcc-target-default-v1.out"
    "$makecmd" -n -f Makefile cross > "$TMPDIR/kcc-target-cross-v1.out"
    cmp "$TMPDIR/kcc-target-default-v1.out" "$TMPDIR/kcc-target-cross-v1.out"
    "$makecmd" -n -f Makefile native > "$TMPDIR/kcc-target-native-v1.out"
    grep -q 'KCPP.dxr\|KCPP\.dxr\|kcpp' "$TMPDIR/kcc-target-native-v1.out"
    if "$makecmd" -n -f Makefile host-built > /dev/null 2>&1; then
        echo 'obsolete host-built alias accepted' >&2; exit 1
    fi
    if "$makecmd" -n -f Makefile native-built > /dev/null 2>&1; then
        echo 'obsolete native-built alias accepted' >&2; exit 1
    fi
done
# The native file is staged in uppercase, but host parsers can validate its
# topology without requiring a host filesystem containing SIXBIT source paths.
python3 - <<'PY'
from pathlib import Path
p=Path('daimos.mk').read_text()
assert '.PHONY: NATIVE INSTALL CLEAN' in p
assert 'NATIVE: B B/KCPP.DXR B/KPARSE.DXR B/KGEN.DXR B/KOPT.DXR B/KCC.DXR' in p
assert not any(line.startswith('ALL:') for line in p.splitlines())
for alias in ('KCPP:', 'KPARSE:', 'KGEN:', 'KOPT:', 'DRIVER:'):
    assert not any(line.startswith(alias) for line in p.splitlines())
PY
echo 'PASS: cross/native target contract in GNU and BSD Make'
