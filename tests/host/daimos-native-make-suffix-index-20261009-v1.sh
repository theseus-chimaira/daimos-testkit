#!/bin/sh
# Check compact suffix-rule indexing and build its PDP-6 object.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('static int\nmake_source_rule(')
b=s.index('static int\nmake_dep_requires_update(',a)
t=s[a:b]
assert 'i < make_suffix_count' in t
assert 'ri = make_suffix_order[i]' in t
assert 'imp->rule = (int)ri;' in t
assert 'i < make_rule_count' not in t
assert 'make_suffix_order[si++] = i;' in s
assert 'make_suffix_count * sizeof(*make_suffix_order)' in s
print('MAKE suffix indexing source invariants: OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
