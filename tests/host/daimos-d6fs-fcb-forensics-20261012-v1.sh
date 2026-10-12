#!/bin/sh
# Read-only per-FCB metadata dump using current d6fsck decoding and layout.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${D6FS_DISK:?set D6FS_DISK}"
: "${TMPDIR:=$HOME/tmp}"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-fcb-forensics-20261012-v1.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
python3 - "$DAIMOS_REPO/tools/host/d6fsck.c" "$work/check.c" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
needle='                if (infos[i].type == D6FS_TYPE_FREE)\n                        continue;\n'
assert src.count(needle) >= 1
# Match only the first FCB decode loop, before extent accounting.
replacement=('                if (i == 0297U || i == 0298U) {\n'
             '                        unsigned w;\n'
             '                        fprintf(stdout, "FORENSIC FCB=%o type=%u parent=%o size=%llu extents=%u\\n", i, infos[i].type, infos[i].parent, (unsigned long long)infos[i].size, infos[i].extents);\n'
             '                        for (w=0; w<FCB_WORDS; ++w) fprintf(stdout, "  word[%u]=%012llo\\n", w, (unsigned long long)f[w]);\n'
             '                }\n')
src=src.replace(needle,replacement+needle,1)
# C integer literal 0297 is invalid octal; index values are decimal.
src=src.replace('i == 0297U || i == 0298U','i == 297U || i == 298U')
Path(sys.argv[2]).write_text(src)
PY
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/check" "$work/check.c"
"$work/check" -n "${D6FS_MEMBERS:-4}" -d "$D6FS_DISK"
