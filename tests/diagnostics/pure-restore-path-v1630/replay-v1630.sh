#!/bin/sh
# Trace original linked PURE restore choices without modifying executable.
# Stop on the first prefix claim, then either the full fallback or commit.
set -eu
: "${PURE_RESTORE_BUILD_V1630:?original 48K v1629 build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-restore-path-v1630.XXXXXX")
trap 'echo "v1630 source-backed restore trace: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_RESTORE_BUILD_V1630" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

boot, work = (Path(sys.argv[1]), Path(sys.argv[2]))
dxrcheck = sys.argv[3]
source = (boot / "boot.ini").read_text(encoding="ascii")
symbols = {}
for line in (boot / "pure-mres-v1612.map").read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        symbols[f[0]] = int(f[1], 8)
original = {
    "proc_pure_restore_v1384": 0o1442,
    "proc_pure_ram_restore_v1391": 0o2207,
    "mm_pure_claim_prefix_v1384": 0o2561,
    "mm_pure_release_prefix_v1384": 0o2563,
    "mm_pure_commit_prefix_v1384": 0o2565,
}
assert {k: symbols.get(k) for k in original} == original, \
    "PURE MRES source layout does not match v1629 build"
image = subprocess.check_output(
    [dxrcheck, "-d", str(boot / "pure-mres-v1612.dxr")],
    text=True, encoding="ascii")
assert re.search(r"(?m)^IMAGE  002561 400000000000$", image), \
    "original claim instruction changed"
assert re.search(r"(?m)^IMAGE  002565 201000000002$", image), \
    "original commit instruction changed"
for unit in range(4):
    key = "attach -q dtc%d " % unit
    matches = [line[len(key):] for line in source.splitlines()
               if line.startswith(key)]
    assert len(matches) == 1
    dest = work / "media" / ("dtc%d.tap" % unit)
    dest.write_bytes(Path(matches[0]).read_bytes())
    source = source.replace(matches[0], str(dest))
source = "\n".join(line for line in source.splitlines()
                    if not line.startswith(("attach -q dsk", "attach -q dr")))
(work / "noaux.ini").write_text(source + "\n", encoding="ascii")
# v1620 separately confirmed installed PURE base 032027 on this
# layout. The actual loaded instruction bytes are examined below.
base = 0o32027
for key, offset in original.items():
    print("v1630 original PURE %s = %06o" % (key, base + offset))
(work / "symbols.txt").write_text("".join(
    "%s %06o\n" % (key, base + offset)
    for key, offset in original.items()), encoding="ascii")
PY
port=$((32000 + ($$ % 11000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+14000))"
python3 - "$work/trace.ini" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
ini = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in ini
tail = 'expect "aaaaax[B"\ngo 020\n'
tail += 'echo V1630_LOADED_INSTRUCTIONS\n'
for addr in (0o34610, 0o34614, 0o34236):
    tail += "examine %06o\n" % addr
tail += 'echo V1630_RESTORE_BEGIN\n'
for addr in (0o34610, 0o34614, 0o34236):
    tail += "break %06o\n" % addr
tail += 'cont\n'
tail += 'echo V1630_FIRST_BRANCH\n'
for ac in (1, 2, 3, 4):
    tail += "examine %o\n" % ac
tail += 'nobreak 034610\n'
tail += 'cont\n'
tail += 'echo V1630_SECOND_BRANCH\n'
for ac in (1, 2, 3, 4):
    tail += "examine %o\n" % ac
tail += 'nobreak\ncont\nexit\n'
path.write_text(ini.replace("go 020\nexit\n", tail, 1),
                encoding="ascii")
PY
set +e
(
    cd "$PURE_RESTORE_BUILD_V1630"
    TERM=dumb timeout -k 3s "${PURE_RESTORE_TIMEOUT_V1630:-500}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1630 simulator exit=$rc"
grep -E 'V1630_|Breakpoint, PC|aaaaax|LwwwwwZ|HALT instruction' \
    "$work/trace.clean" | tail -28 || :
test "$rc" -eq 0
grep -q '^V1630_SECOND_BRANCH$' "$work/trace.clean"
# Debugger breakpoints insert transcript output after the parent's L
# before the children return. The terminal w/Z sequence remains exact.
grep -q 'wwwwwZ' "$work/trace.clean"
grep -q 'HALT instruction' "$work/trace.clean"
