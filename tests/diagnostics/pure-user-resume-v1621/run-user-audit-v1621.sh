#!/bin/sh
# Audit exact physical v1620 MM/scheduler writes, plus the actual resumed
# child C marker from its saved PURE DXR2 TSFS image and source.
set -eu
: "${PURE_BRK_BUILD_V1615:?matching physical 48K boot required}"
: "${PURE_USER_TRACE_V1621:?post-scheduler physical trace required}"
: "${PURE_GUEST_SOURCE_V1621:?preserved compiled guest source required}"
: "${PURE_GUEST_IMAGE_V1621:?preserved booted guest image required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-user-audit-v1621.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

# v1620's MM/scheduler watchpoint parser owns one snapshot per breakpoint.
# v1621 additionally resumes CPU time; later snapshots legitimately change
# current-slot and MM owners. Restrict the older audit to its original
# watchpoint boundary rather than conflating post-resume observations.
python3 - "$PURE_USER_TRACE_V1621" "$work/watchpoint.clean" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
end = s.index("Step expired, PC:")
assert "Breakpoint, PC: 016770 " in s[:end]
Path(sys.argv[2]).write_text(s[:end])
PY
PURE_FOLLOW_TRACE_V1620="$work/watchpoint.clean"
PURE_FOLLOW_MODE_V1620=scheduler
export PURE_FOLLOW_TRACE_V1620 PURE_FOLLOW_MODE_V1620
sh "$here/../pure-prefix-boundary-v1620/run-follow-audit-v1620.sh"

audit()
{
    python3 "$here/audit-user-v1621.py" "$1" "$2" \
        "$PURE_BRK_BUILD_V1615/tsfs-root.manifest" \
        "$PURE_GUEST_IMAGE_V1621" "$PDP10_PREFIX/bin/dxrcheck"
}
audit "$PURE_USER_TRACE_V1621" "$PURE_GUEST_SOURCE_V1621"

python3 - "$PURE_USER_TRACE_V1621" "$PURE_GUEST_SOURCE_V1621" \
    "$work/missing-w.clean" "$work/wrong-source.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
start = s.index("Breakpoint, PC: 016770 ")
end = s.index("Step expired, PC:", start)
before = s[start:end]
assert before.count("\nw\n") == 1, "restored user marker changed"
Path(sys.argv[3]).write_text(
    s[:start] + before.replace("\nw\n", "\nx\n", 1) + s[end:])
src = Path(sys.argv[2]).read_text()
assert src.count("p14_char('w')") == 1
Path(sys.argv[4]).write_text(src.replace(
    "p14_char('w')", "p14_char('x')", 1))
PY
for variant in marker source; do
    if [ "$variant" = marker ]; then
        trace="$work/missing-w.clean"
        source="$PURE_GUEST_SOURCE_V1621"
    else
        trace="$PURE_USER_TRACE_V1621"
        source="$work/wrong-source.c"
    fi
    if audit "$trace" "$source" >"$work/$variant.log" 2>&1; then
        echo "FAIL v1621: unsafe $variant mutation accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1621 user resume audit:' "$work/$variant.log" || {
        cat "$work/$variant.log" >&2
        exit 1
    }
    echo "PASS v1621: unsafe $variant mutation rejected"
done
