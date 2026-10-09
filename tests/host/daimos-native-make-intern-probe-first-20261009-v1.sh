#!/bin/sh
# Existing dependency names must be checked before a hash table rehash.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('static unsigned int\nmake_dep_intern(')
b=s.index('static char *\nmake_trim(',a)
t=s[a:b]
assert t.index('if (make_streq(make_text(off), name))') < t.index('table = realloc(0, size * sizeof(*table));')
assert t.index('make_dep_names_count + 1U') > t.index('if (make_streq(make_text(off), name))')
assert t.count('make_dep_names[slot] = off + 1U') == 1
print('Native MAKE probe-before-growth invariants: OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
