#!/bin/sh
# Require actual physical lifecycle and reject altered user evidence.
set -eu
: "${PURE_LIFECYCLE_BUILD_V1627:?preserved original physical build required}"
: "${PURE_LIFECYCLE_TRACE_V1627:?preserved simulator trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-lifecycle-audit-v1627.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source="$PURE_LIFECYCLE_BUILD_V1627/../user/init-v1614.c"
manifest="$PURE_LIFECYCLE_BUILD_V1627/tsfs-root.manifest"
dxrlog="$PURE_LIFECYCLE_BUILD_V1627/../user/dxrcheck.log"
python3 "$here/audit-v1627.py" "$source" "$PURE_LIFECYCLE_TRACE_V1627" \
    "$manifest" "$dxrlog"
python3 - "$PURE_LIFECYCLE_TRACE_V1627" "$work/exit-mutant" \
    "$work/word-mutant" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding="ascii")
a = "LwwwwwwZ"
b = "[A103470/042522]"
assert s.count(a) == 1 and s.count(b) == 1
Path(sys.argv[2]).write_text(s.replace(a, "LwwwwwwY", 1),
                              encoding="ascii")
Path(sys.argv[3]).write_text(s.replace(b, "[A103471/042522]", 1),
                              encoding="ascii")
PY
for mutant in exit-mutant word-mutant; do
    if python3 "$here/audit-v1627.py" "$source" "$work/$mutant" \
        "$manifest" "$dxrlog" >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1627: altered physical $mutant was accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1627 physical lifecycle:' "$work/$mutant.log"
done
echo 'PASS v1627: false parent status and MM word count rejected'
