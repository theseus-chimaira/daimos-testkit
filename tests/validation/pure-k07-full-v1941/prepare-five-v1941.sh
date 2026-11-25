#!/bin/sh
# Change only the historical pressure fixture's child count. Retain the
# sixth RUN refusal, plain child and compressed FULL children, actual
# WAIT checks and identical production KCORE/KINIT/MRES images.
set -eu
: "${DAIMOS_REPO:?source-matched DAIMOS checkout required}"
: "${V1941_ORIGINAL_BUILD:?original six-child v1940 build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
old=$(CDPATH= cd -- "$V1941_ORIGINAL_BUILD" && pwd)
work=$(mktemp -d "$TMPDIR/pure-k07-five-v1941.XXXXXX")
trap 'echo "v1941 five-child fixture: $work"' EXIT
b="$work/build"
mkdir -p "$b/media" "$work/user"
python3 "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-v1638.py" \
    "$kit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/user/init-v1941.c"
python3 - "$work/user/init-v1941.c" "$old/../user/init-v1614.c" <<'PY'
from pathlib import Path
import sys
p, old = map(Path, sys.argv[1:])
s = p.read_text()
assert s == old.read_text(), "original fixture source does not match generator"
assert s.count("#define P14_CHILDREN         6U") == 1
s = s.replace("#define P14_CHILDREN         6U",
              "#define P14_CHILDREN         5U")
s = s.replace("Seventh RUN", "Sixth RUN").replace("a seventh complete", "a sixth complete").replace("six existing kids", "five existing kids")
p.write_text(s)
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
"$cc" -std=c99 -Os $incs -S "$work/user/init-v1941.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
# The original CRT and syscall veneers were built from the exact source.
cp "$old/../user/crt0.dobj" "$old/../user/syscall.dobj" "$work/user/"
libgcc=$("$cc" -print-libgcc-file-name)
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/dlink-v1941" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
"$work/dlink-v1941" --pure -b 020 -o "$work/user/init.dxr" \
    -M "$work/user/init.map" "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
"$PDP10_PREFIX/bin/dxrcheck" -d "$work/user/init.dxr" >"$work/user/dxrcheck.log"
grep -q 'purity=PURE' "$work/user/dxrcheck.log"
for name in kcore.dxr kcore.map kinit.lowmem.words pure-mres-v1612.dxr \
    pure-mres-v1612.map stage1-dtc.pt d6block-v1464 mktsfs-v1461 tsfscheck-v1461; do
    cp "$old/$name" "$b/$name"
    cmp "$old/$name" "$b/$name"
done
# Reuse the original verified package sources, replacing only INIT.
# Keep private boot media, log and output paths.
cp "$old/media/dtc3-home-v22.tap" "$old/media/mtc0.tap" "$old/media/mtc1.tap" "$b/media/"
python3 - "$old" "$b" "$work" <<'PY'
from pathlib import Path
import sys
old, b, work = map(Path, sys.argv[1:])
s = (old / "tsfs-root.manifest").read_text()
old_init = "F /SYSTEM/INIT " + str(old.parent / "user/init.dxr")
assert s.count(old_init) == 1
assert "F /SYSTEM/COMP " not in s
(b / "tsfs-root.manifest").write_text(s.replace(old_init,
    "F /SYSTEM/INIT " + str(work / "user/init.dxr"), 1))
ini = (old / "boot.ini").read_text().replace(str(old)+"/", str(b)+"/")
(b / "boot.ini").write_text(ini)
PY
sh "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh" "$work" "$b"
echo "PASS v1941: source-derived five-child guest built; original kernel images identical"
echo "V1941_BUILD=$b"
