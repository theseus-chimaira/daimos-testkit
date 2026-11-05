#!/bin/sh
# Regression: modern zero-reservation layout is not a legacy DBOOT header.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-explicit-zero-v1192.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

make -s -C "$DAIMOS_REPO/tools/host" \
    BUILD_ROOT="$work/build" \
    "$work/build/tools/host/mkdsk" \
    "$work/build/tools/host/mkd6fs" \
    "$work/build/tools/host/d6fsck"
tools="$work/build/tools/host"
: > "$work/empty.words"

# A modern, explicit zero-length bootstream, LOGSTORE and BADMAP is valid.
"$tools/mkdsk" -n 1 -m clean -p "$work/empty.words" \
    -o "$work/modern" --d6fs-layout --logstore-blocks 0 \
    --badmap-blocks 0 --swap-tail-blocks 0 --spare-blocks 0 \
    --member-sectors 02000
"$tools/mkd6fs" -n 1 -d "$work/modern" > "$work/modern.mklog" 2>&1
"$tools/d6fsck" -n 1 -d "$work/modern" > "$work/modern.cklog" 2>&1
! grep -qi 'legacy' "$work/modern.mklog" "$work/modern.cklog"
grep -q ': clean$' "$work/modern.cklog"

# A zero marker remains a readable legacy header, including its warning.
cp -R "$work/modern" "$work/legacy"
python3 - "$work/legacy/dsk0.dsk" 0 <<'PY'
import struct
import sys
with open(sys.argv[1], 'r+b') as f:
    f.seek(0o20 * 8)
    f.write(struct.pack('<Q', int(sys.argv[2])))
PY
"$tools/mkd6fs" -n 1 -d "$work/legacy" > "$work/legacy.mklog" 2>&1
"$tools/d6fsck" -n 1 -d "$work/legacy" > "$work/legacy.cklog" 2>&1
grep -q 'warning: legacy D6FSR2 layout' "$work/legacy.mklog"
grep -q 'note: legacy layout' "$work/legacy.cklog"
grep -q ': clean$' "$work/legacy.cklog"

# Unknown extension flags cannot be mistaken for either accepted format.
cp -R "$work/modern" "$work/invalid"
python3 - "$work/invalid/dsk0.dsk" 2 <<'PY'
import struct
import sys
with open(sys.argv[1], 'r+b') as f:
    f.seek(0o20 * 8)
    f.write(struct.pack('<Q', int(sys.argv[2])))
PY
if "$tools/mkd6fs" -n 1 -d "$work/invalid" > "$work/invalid.mklog" 2>&1; then
    echo 'v1192: invalid flags accepted by mkd6fs' >&2
    exit 1
fi
if "$tools/d6fsck" -n 1 -d "$work/invalid" > "$work/invalid.cklog" 2>&1; then
    echo 'v1192: invalid flags accepted by d6fsck' >&2
    exit 1
fi
grep -q 'unknown D6FS reserved-layout flags' "$work/invalid.mklog"
grep -q 'unknown reserved-layout flags' "$work/invalid.cklog"

# High bits of the 36-bit flags word must not be truncated to host unsigned.
cp -R "$work/modern" "$work/highbits"
python3 - "$work/highbits/dsk0.dsk" <<'PY'
import struct
import sys
with open(sys.argv[1], 'r+b') as f:
    f.seek(0o20 * 8)
    f.write(struct.pack('<Q', (1 << 34) | 1))
PY
if "$tools/mkd6fs" -n 1 -d "$work/highbits" > "$work/highbits.mklog" 2>&1; then
    echo 'v1192: high layout flag bit accepted by mkd6fs' >&2
    exit 1
fi
if "$tools/d6fsck" -n 1 -d "$work/highbits" > "$work/highbits.cklog" 2>&1; then
    echo 'v1192: high layout flag bit accepted by d6fsck' >&2
    exit 1
fi

# Different modern/legacy descriptor modes in one set are invalid.
"$tools/mkdsk" -n 2 -m clean -p "$work/empty.words" \
    -o "$work/mixed" --d6fs-layout --logstore-blocks 0 \
    --badmap-blocks 0 --swap-tail-blocks 0 --spare-blocks 0 \
    --member-sectors 02000,02000
python3 - "$work/mixed/dsk1.dsk" <<'PY'
import struct
import sys
with open(sys.argv[1], 'r+b') as f:
    f.seek(0o20 * 8)
    f.write(struct.pack('<Q', 0))
PY
if "$tools/mkd6fs" -n 2 -d "$work/mixed" > "$work/mixed.mklog" 2>&1; then
    echo 'v1192: mixed layout markers accepted by mkd6fs' >&2
    exit 1
fi
if "$tools/d6fsck" -n 2 -d "$work/mixed" > "$work/mixed.cklog" 2>&1; then
    echo 'v1192: mixed layout markers accepted by d6fsck' >&2
    exit 1
fi

echo 'v1192: explicit zero, legacy, invalid/high bits and mixed markers PASS'
