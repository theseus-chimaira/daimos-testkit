#!/bin/sh
# Verify that MAKE stores newer flags during DFS and never restats for $? .
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('static int\nmake_build(const char *name, struct make_result *out, unsigned int depth)\n{')
b=s.index('static int\nmake_command_assignment',a)
body=s[a:b]
assert 'make_mark_newer(di, dep.changed ||' in body
assert 'make_is_newer(di)' in body
assert 'implicit_newer = dep.changed ||' in body
section=body.split('if (need && recipe != MAKE_NONE && make_uses_newer(recipe)) {',1)[1].split('if (need && recipe != MAKE_NONE) {',1)[0]
assert 'make_stat(' not in section
assert 'make_newer_add(' in section
assert 'make_dep_newer = realloc' in s
print('MAKE packed prerequisite metadata: source invariants OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
