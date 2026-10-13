#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
work="$TMPDIR/d6codec-tsfs-v069-check"
mkdir -p "$work"
make -s -C "$DAIMOS_REPO/tools/host" BUILD="$work" \
  "$work/mktsfs" "$work/tsfscheck" \
  "$work/mktsfs-v069" "$work/tsfscheck-v069"
python3 - "$work" <<'PY'
import pathlib
import struct
import sys
p = pathlib.Path(sys.argv[1])
(p/'source.words').write_bytes(b''.join(struct.pack('<Q', 0) for _ in range(256)))
(p/'manifest').write_text('F /TEST ' + str(p/'source.words') + '\n')
PY
"$work/mktsfs-v069" -n 1 -i 1:2 -m "$work/manifest" -o "$work/new"
"$work/tsfscheck-v069" "$work/new0.dta"
if "$work/tsfscheck" "$work/new0.dta" >/dev/null 2>&1; then
    echo 'FAIL legacy checker accepted inline TSFS media' >&2
    exit 1
fi
"$work/mktsfs" -n 1 -i 1:2 -m "$work/manifest" -o "$work/old"
"$work/tsfscheck" "$work/old0.dta"
if "$work/tsfscheck-v069" "$work/old0.dta" >/dev/null 2>&1; then
    echo 'FAIL v069 checker accepted legacy TSFS media' >&2
    exit 1
fi
printf '%s\n' 'PASS D6 inline TSFS v069 isolated format and bidirectional incompatibility'
