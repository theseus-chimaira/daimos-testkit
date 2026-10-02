#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-mtc516-online-v1-$$"
media0="$work/rw.tap"
media1="$work/eot.tap"
ini="$work/mtc.ini"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

# A sparse one-million-byte SIMH record reaches the configured 1 MB MTC1
# capacity with one spacing command.  The payload bytes are irrelevant because
# the oracle spaces the record rather than reading it through the 32K buffer.
python3 - "$media1" <<'PY'
import struct
import sys

path = sys.argv[1]
record_bytes = 1000000
with open(path, "wb") as f:
    f.write(struct.pack("<I", record_bytes))
    f.seek(4 + record_bytes)
    f.write(struct.pack("<I", record_bytes))
PY

cat > "$ini" <<EOF2
set DCT enabled
set MTC enabled
set MTC0 enabled
set MTC0 7T
set MTC0 WRITEENABLED
set MTC DCT=0
attach -q -n MTC0 $media0
set MTC1 enabled
set MTC1 7T
set MTC2 enabled
set MTC1 LENGTH=1
attach -q MTC1 $media1
EOF2

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 30 --workdir "$work/run" \
        --name daimos-mtc516-online-v1 --ini "$ini" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-mtc516-online-v1.s" \
        "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
    "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
        "$self/daimos-mtc516-online-stubs-v1.s" >/dev/null

printf '%s\n' 'mtc516-online: PASS (record R/W, rewind, filemark, spacing, EOF, EOT)'
