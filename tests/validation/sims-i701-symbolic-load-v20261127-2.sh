#!/bin/sh
# IBM 701 upstream symbolic LOAD and half-word addressing smoke test.
# Use a private directory so the test cannot change simulator source files.
set -eu
: "${TMPDIR:=$HOME/tmp}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
export TMPDIR
simh=${SIMH_I701:-$PDP10_PREFIX/bin/i701}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/sims-i701-symbolic-load-v20261127-2.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/check.sym" <<'DATA'
0000: OCT 123456
0001: OCT 654321
0002: NO OP
14000: OCT 777777
DATA
cat > "$work/check.ini" <<'DATA'
load check.sym
examine 0-3
examine 10000
examine -m 2
quit
DATA
if ! (cd "$work" && timeout 15 "$simh" check.ini </dev/null >check.log 2>&1); then
    cat "$work/check.log" >&2
    exit 1
fi
if ! awk '
    $1 == "0:" && $2 == "123456" { a=1 }
    $1 == "1:" && $2 == "654321" { b=1 }
    $1 == "2:" && $2 == "100000" && $3 == "NO" && $4 == "OP" { c=1 }
    $1 == "3:" && $2 == "000000" { d=1 }
    $1 == "10000:" && $2 == "123456654321" { e=1 }
    END { if (!(a && b && c && d && e)) exit 1 }
' "$work/check.log"; then
    cat "$work/check.log" >&2
    exit 1
fi
echo 'PASS: IBM 701 symbolic LOAD, half-word storage, address guard and spaced mnemonic'
