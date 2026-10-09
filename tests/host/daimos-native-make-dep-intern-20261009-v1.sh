#!/bin/sh
# Check MAKE's dependency name interning and build its PDP-6 object.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('static unsigned int\nmake_dep_intern(')
b=s.index('static char *\nmake_trim(',a)
sub=s[a:b]
assert 'make_streq(make_text(off), name)' in sub
assert 'make_dep_names[slot] = off + 1U;' in sub
assert 'free(make_dep_names);' in sub
assert 'make_dep_intern(name);' in s
print('Native MAKE dependency interning structural checks: OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
