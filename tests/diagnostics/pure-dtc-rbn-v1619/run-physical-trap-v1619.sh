#!/bin/sh
# Reproduce EXACT original tape MRES binary with test-only symbol exports,
# then break the full 48K PURE guest on physical PI3 RBN match or failure.
# No modified driver is booted; only the original v1618 DXR is installed.
set -eu
: "${DAIMOS_REPO:?DAIMOS source required}"
: "${PURE_BRK_BUILD_V1615:?matching full 48K opt-in PURE build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/dtc-rbn-trap-v1619.XXXXXX")
if [ "${KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
python3 - "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
    "$work/tape-symbols.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
needle = '        .globl tape_pi_handler\n'
assert s.count(needle) == 1
repl = (needle + '        .globl dtc_search_pi_found\n' +
        '        .globl dtc_search_fail\n' +
        '        .globl dtc_search_pi_read\n' +
        '        .globl tape_dct_done_keep_dtc\n')
Path(sys.argv[2]).write_text(s.replace(needle, repl, 1))
PY
das -C -F -O "$work/tape-symbols.dobj" "$work/tape-symbols.s"
dlink -b 0 -A "$PURE_BRK_BUILD_V1615/kcore.map" \
    -o "$work/tape-symbols.dxr" -M "$work/tape-symbols.map" \
    -R "$work/tape-symbols-mres.dobj" -N tape_mres_package \
    -X tape_pi_handler -X dtc_read_block -X mtc_service \
    -X dtc_write_block -X tape_dct_handler \
    -X tape_watchdog_tick_v1089 \
    -X dtc_search_pi_found -X dtc_search_fail \
    -X dtc_search_pi_read -X tape_dct_done_keep_dtc \
    "$work/tape-symbols.dobj"
python3 - "$PURE_BRK_BUILD_V1615/tape-mres.dxr" \
    "$work/tape-symbols.dxr" "$work/tape-symbols.map" <<'PY'
import re
import subprocess
import sys
from pathlib import Path


def image(path):
    text = subprocess.check_output(["dxrcheck", "-d", path], text=True)
    return {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", text)}


sym = {}
for line in Path(sys.argv[3]).read_text().splitlines():
    parts = line.split()
    if len(parts) > 1 and not parts[1].strip("01234567"):
        sym[parts[0]] = int(parts[1], 8)
assert image(sys.argv[1]) == image(sys.argv[2]), "code image changed"
assert sym["dtc_search_pi_found"] == 0o415
assert sym["dtc_search_fail"] == 0o463
assert sym["dtc_search_pi_read"] == 0o455
assert sym["tape_dct_done_keep_dtc"] == 0o124
print("PASS v1619: physical PI3 symbols anchored to identical TAPE DXR")
print("  found 031046; search failure 031114 (octal)")
print("  PI3 read arm 031106; DCT READ completion 030555")
PY

PURE_RBN_FOUND_BREAK_V1619=1
PURE_RBN_MAP_V1619="$work/tape-symbols.map"
PURE_CONSOLE_STOP_V1616='<010000+020000>'
PURE_REPLAY_TIMEOUT_V1615=${PURE_RBN_TRAP_TIMEOUT_V1619:-320}
export PURE_RBN_FOUND_BREAK_V1619 PURE_RBN_MAP_V1619
export PURE_CONSOLE_STOP_V1616 PURE_REPLAY_TIMEOUT_V1615
echo 'v1619: trap original physical 48K RBN-match or search-failure'
sh "$here/../pure-brk-refusal-v1615/replay-v1615.sh"
