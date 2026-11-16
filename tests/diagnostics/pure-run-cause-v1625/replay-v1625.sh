#!/bin/sh
# Run the exact v1624 six-child guest again, stopping on ORIGINAL RUN
# error-path instructions rather than guessing from the returned PID.
set -eu
: "${PURE_RUN_BUILD_V1625:?point to preserved v1624 six-child build}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-run-cause-v1625.XXXXXX")
trap 'echo "v1625 original RUN stage evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_RUN_BUILD_V1625" "$work" <<'PY'
from pathlib import Path
import re
import sys

boot, root = map(Path, sys.argv[1:])
source = (boot / "boot.ini").read_text(encoding="ascii")
symbols = {}
for line in (boot / "kcore.map").read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
sites = ("proc_run_startup_failed", "proc_run_mm_bad",
         "proc_run_claimed_bad", "proc_run_bad")
for item in sites + ("mm_extents", "mm_extent_count", "mm_arenas",
                     "mm_arena_count", "proc_high_slot",
                     "proc_current_slot", "proc_slots"):
    assert item in symbols, "original KCORE symbol missing: " + item
addresses = [symbols[x] for x in sites]
assert addresses == [0o17722, 0o17724, 0o17725, 0o17727], \
    "v1624 linked RUN stage layout changed"
for unit in range(4):
    key = "attach -q dtc%d " % unit
    paths = [line[len(key):] for line in source.splitlines()
             if line.startswith(key)]
    assert len(paths) == 1
    data = Path(paths[0]).read_bytes()
    dest = root / "media" / ("dtc%d.tap" % unit)
    dest.write_bytes(data)
    source = source.replace(paths[0], str(dest))
source = "\n".join(line for line in source.splitlines()
                    if not line.startswith(("attach -q dsk", "attach -q dr")))
(root / "noaux.ini").write_text(source + "\n", encoding="ascii")
(root / "sites.txt").write_text("\n".join("%s %06o" % (x, symbols[x])
                            for x in sites) + "\n", encoding="ascii")
print("v1625: original linked RUN refusal sites:")
print((root / "sites.txt").read_text(), end="")
PY
port=$((32000 + ($$ % 12000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+13000))"
python3 - "$PURE_RUN_BUILD_V1625/kcore.map" "$work/trace.ini" <<'PY'
from pathlib import Path
import re
import sys
symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
path = Path(sys.argv[2])
source = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in source
tail = ""
for label in ("proc_run_startup_failed", "proc_run_mm_bad",
              "proc_run_claimed_bad", "proc_run_bad"):
    tail += "break %06o\n" % symbols[label]
tail += "show break\ngo 020\n"
for reg in (1, 2, 12, 13):
    tail += "examine %o\n" % reg
for label in ("proc_current_slot", "proc_high_slot", "proc_slots",
              "mm_extent_count", "mm_arena_count"):
    tail += "examine %06o\n" % symbols[label]
tail += "examine %06o-%06o\n" % (
    symbols["mm_arenas"], symbols["mm_arenas"] + 7)
tail += "examine %06o-%06o\n" % (
    symbols["mm_extents"], symbols["mm_extents"] + 95)
tail += "exit\n"
path.write_text(source.replace("go 020\nexit\n", tail, 1), encoding="ascii")
PY
set +e
(
    cd "$PURE_RUN_BUILD_V1625"
    TERM=dumb timeout -k 3s "${PURE_RUN_TIMEOUT_V1625:-390}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
grep -E 'PURE[[:space:]]+LOADED|aaaaa|Breakpoint, PC:|^0*[0-7]+:' \
    "$work/trace.clean" | tail -28 || :
echo "v1625: physical simulator status=$rc"
echo "v1625: trace $work/trace.clean"
if grep -q 'Breakpoint, PC: 017722 ' "$work/trace.clean"; then
    echo 'v1625: RUN startup failure branch reached'
elif grep -q 'Breakpoint, PC: 017724 ' "$work/trace.clean"; then
    echo 'v1625: RUN MM allocation failure branch reached'
elif grep -q 'Breakpoint, PC: 017725 ' "$work/trace.clean"; then
    echo 'v1625: RUN claimed-child discard path reached'
elif grep -q 'Breakpoint, PC: 017727 ' "$work/trace.clean"; then
    echo 'v1625: RUN direct validation/slot failure branch reached'
else
    echo 'v1625: INCONCLUSIVE; no original RUN failure stage reached' >&2
    exit 1
fi
