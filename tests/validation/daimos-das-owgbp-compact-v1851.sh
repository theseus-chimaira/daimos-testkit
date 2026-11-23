#!/bin/sh
# Exhaustively check defined OWGBP 6/7/8/9/18-bit selector ranges.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
das=${DAS_BIN_V1851:-"$PDP10_PREFIX/bin/das"}
work=$(mktemp -d "$TMPDIR/das-owgbp-v1851.XXXXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "evidence: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
python3 "$base/daimos-das-owgbp-compact-v1851.py" generate "$work/accepted.s"
"$das" -A -O "$work/accepted.dxr" "$work/accepted.s"
python3 "$base/daimos-das-owgbp-compact-v1851.py" check "$work/accepted.dxr"
for sel in 0 45 54 61 67 74 77 100; do
    printf '.text\nstart:\n    OWGBP 0%s,GIW 0123456\n' "$sel" > "$work/invalid.s"
    if "$das" -A -O "$work/invalid.dxr" "$work/invalid.s" >/dev/null 2>&1; then
        echo "DAS accepted invalid OWGBP selector 0$sel" >&2
        exit 1
    fi
done
echo 'PASS: invalid OWGBP selectors rejected'
