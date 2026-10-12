#!/bin/sh
# Read-only inspected directory-reference identities using the real d6fsck traversal.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${D6FS_DISK:?set D6FS_DISK}"
: "${TMPDIR:=$HOME/tmp}"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-dirent-identity-20261012-v1.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
python3 - "$DAIMOS_REPO/tools/host/d6fsck.c" "$work/d6fsck.c" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
needle='                        ++refs[child];\n'
assert src.count(needle)==1, 'directory walker changed'
probe=('                        if (child == 297U || child == 298U) {\n'
       '                                unsigned k;\n'
       '                                fprintf(stdout, "DIRENT child=%o parent=%o slot=%llu type=%u name=", child, di, (unsigned long long)(off / DIRENT_WORDS), type);\n'
       '                                for (k=0; k<4U; ++k) fprintf(stdout, "%012llo%s", (unsigned long long)name[k], k==3U ? "\\n" : ":");\n'
       '                        }\n')
src=src.replace(needle,probe+needle,1)
needle2='        for (i = 0; i < s->fcb_count; ++i) {\n                uint64_t *f;\n'
assert src.count(needle2)==1
probe2=('        for (i=297U;i<=298U;++i)\n'
        '                fprintf(stdout, "IDENTITY FCB=%o type=%u parent=%o size=%llu refs=%u reachable=%u\\n", i, infos[i].type, infos[i].parent, (unsigned long long)infos[i].size, refs[i], reachable[i]);\n')
src=src.replace(needle2,probe2+needle2,1)
Path(sys.argv[2]).write_text(src)
PY
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/d6fsck" "$work/d6fsck.c"
"$work/d6fsck" -n "${D6FS_MEMBERS:-4}" -d "$D6FS_DISK"
