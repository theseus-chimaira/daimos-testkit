#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
out="$TMPDIR/d6codec-tsfs-v074-test"
mkdir -p "$out"
make -s -C "$DAIMOS_REPO/tools/host" BUILD="$out" "$out/mktsfs-v069" "$out/tsfscheck-v069"
python3 - "$out" <<'PY'
import pathlib, struct, sys
p = pathlib.Path(sys.argv[1])
(p/'zeros.words').write_bytes(struct.pack('<Q',0)*256)
(p/'manifest').write_text('F /TEST '+str(p/'zeros.words')+'\n')
PY
"$out/mktsfs-v069" -n 1 -i 1:2 -m "$out/manifest" -o "$out/media"
"$out/tsfscheck-v069" "$out/media0.dta"
cc -std=c99 -O2 -Wall -Wextra -Werror -I"$DAIMOS_REPO/tools/host" \
 -o "$out/inspect-v074" "$(dirname "$0")/inspect-v074.c" "$DAIMOS_REPO/tools/host/tsfs-format.c"
"$out/inspect-v074" "$out/media0.dta"
