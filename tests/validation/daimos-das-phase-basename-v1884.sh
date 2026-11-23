#!/bin/sh
# Exercise the actual host phase-file path and the noncolliding fallback.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${DAS_ROOT:?DAS_ROOT must name the DAS checkout}"
work=$(mktemp -d "$TMPDIR/das-phase-basename-v1884.XXXXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
printf 'START: MOVE 1,2\n END START\n' > "$work/INPUT.S"

# A marker at the obsolete name must survive; the new name must be removed.
printf 'obsolete\n' > "$work/PROGRAM.DXR.D2R"
printf 'scratch\n' > "$work/PROGRAM.D2R"
"$DAS_ROOT/das" -O "$work/PROGRAM.DXR" "$work/INPUT.S"
test -s "$work/PROGRAM.DXR"
test ! -e "$work/PROGRAM.D2R"
test "$(cat "$work/PROGRAM.DXR.D2R")" = obsolete

# Never reuse the output itself as a temporary file.
"$DAS_ROOT/das" -O "$work/OUTPUT.D2R" "$work/INPUT.S"
test -s "$work/OUTPUT.D2R"
test ! -e "$work/OUTPUT.D2R.D2R"

# Preserve other historical output suffixes, for compatibility.
printf 'old\n' > "$work/PROGRAM.BIN.D2R"
"$DAS_ROOT/das" -O "$work/PROGRAM.BIN" "$work/INPUT.S"
test -s "$work/PROGRAM.BIN"
test ! -e "$work/PROGRAM.BIN.D2R"

echo 'PASS: phase filename uses PROGRAM.D2R and preserves fallback v1884'
