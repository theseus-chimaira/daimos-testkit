#!/bin/sh
# Regression for SIMH's CPU register-table PC-first invariant.  GO address
# must modify PC, not the PDP-6 instruction histogram's OPCOUNT register.
set -eu
: "${TMPDIR:?Set TMPDIR}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"

simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
work="$TMPDIR/simh-pdp6-go-pc-v155-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cat > "$work/boot.ini" <<'EOF'
deposit 1000 254200001000
go 1000
examine PC
exit
EOF

if ! SDL_VIDEODRIVER=dummy TERM=dumb timeout 5 "$simh" \
    "$work/boot.ini" > "$work/boot.log" 2>&1; then
    cat "$work/boot.log" >&2
    echo 'FAIL: PDP-6 GO did not halt at the requested address' >&2
    exit 1
fi
if ! grep -F 'HALT instruction, PC: 001000' "$work/boot.log" >/dev/null ||
    ! grep -E '^PC:[[:space:]]+001000' "$work/boot.log" >/dev/null; then
    cat "$work/boot.log" >&2
    echo 'FAIL: PDP-6 GO did not update PC to 001000' >&2
    exit 1
fi
echo 'PASS: PDP-6 GO address selects PC and executes HALT'
