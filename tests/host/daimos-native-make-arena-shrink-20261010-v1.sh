#!/bin/sh
# Verify post-parse arena compaction and native-word alignment.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a=s.index('if (make_parse_file(makefile) != 0)')
b=s.index('/* A separate suffix index',a)
t=s[a:b]
assert 'make_arena_used +' in t
assert '(MAKE_MAX_DEPTH + 1U) * MAKE_IMPLICIT_SLOT_CHARS' in t
assert 'needed = (needed + sizeof(kword_t) - 1U)' in t
assert 'realloc(make_arena, needed)' in t
assert 'if (smaller != 0)' in t
print('MAKE arena post-parse alignment and shrink: OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
