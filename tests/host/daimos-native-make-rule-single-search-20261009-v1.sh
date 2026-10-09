#!/bin/sh
# Verify insertion reuses binary-search lower bound.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
x=s.split('static int\nmake_get_rule(',1)[1].split('static int\nmake_add_dep(',1)[0]
assert x.count('make_rule_lower_bound(name)') == 1
assert 'make_find_rule(name)' not in x
assert 'make_rule_order[pos] = (unsigned int)ri;' in x
print('Native MAKE insertion search reuse: OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
