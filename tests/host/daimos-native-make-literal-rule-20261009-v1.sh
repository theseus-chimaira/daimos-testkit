#!/bin/sh
# Confirm native MAKE retains variable expansion for referenced rules.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('static int\nmake_parse_rule(')
b=s.index('static int make_stat(',a)
t=s[a:b]
assert "line[i] != '$'" in t
assert "if (line[i] == '$')" in t
assert 'make_expand(line, make_expand_buf,' in t
assert 'colon = line;' in t
print('Literal dependency parser path: source invariants OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
