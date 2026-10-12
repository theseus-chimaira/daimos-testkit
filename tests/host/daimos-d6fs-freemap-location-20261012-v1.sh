#!/bin/sh
# Test-only: locate D6FS allocation-map block from validated d6fsck superblock.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO required}"
: "${D6FS_DISK:?D6FS_DISK required}"
: "${TMPDIR:=$HOME/tmp}"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-freemap-location-20261012-v1.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
python3 - "$DAIMOS_REPO/tools/host/d6fsck.c" "$work/d6fsck.c" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
needle='        fprintf(stderr, "d6fsck: selected superblock %o seq=%llo state=%s\\n",'
assert source.count(needle)==1, 'd6fsck superblock reporting changed'
source=source.replace(needle, '        fprintf(stdout, "D6FS_FREEMAP_START=%u\\n", s->freemap_start);\n'+needle,1)
Path(sys.argv[2]).write_text(source)
PY
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/d6fsck" "$work/d6fsck.c"
"$work/d6fsck" -n "${D6FS_MEMBERS:-4}" -d "$D6FS_DISK"
