#!/bin/sh
# Isolated host KCC induction-pointer call-safety regression (C89).
set -eu
: "${HOST_KCC:?set HOST_KCC to the exact host KCC executable under test}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=${V1395_WORK:-$TMPDIR/kcc-indptr-call-v1395}
if [ -e "$work" ]; then
    echo "v1395: refusing to overwrite $work" >&2
    exit 2
fi
mkdir -p "$work"
"$HOST_KCC" -Pgnu99 -O -x=pdp6 -m=gas -S \
    "$here/indptr-call-v1395.c" -o "$work/call-opt-v1395.s"
"$HOST_KCC" -Pgnu99 -O=gen -x=pdp6 -m=gas -S \
    "$here/indptr-call-v1395.c" -o "$work/call-gen-v1395.s"
"$HOST_KCC" -Pgnu99 -O -x=pdp6 -m=gas -S \
    "$here/indptr-nocall-v1395.c" -o "$work/nocall-opt-v1395.s"
python3 -B "$here/check-v1395.py" "$work/call-opt-v1395.s" \
    "$work/call-gen-v1395.s" "$work/nocall-opt-v1395.s"
