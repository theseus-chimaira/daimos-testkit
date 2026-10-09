#!/bin/sh
# The optional resolved rule ID shares the dependency text word.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert '#define MAKE_NONE        0777777U' in s
assert '(*dep_ref >> 18) - 1U' in s
assert '*dep_ref |= ((unsigned int)ri + 1U) << 18' in s
assert 'make_deps[di].text & MAKE_NONE' in s
assert 'make_build(depname, &dep, depth + 1U,' in s
assert '&make_deps[di].text);' in s
assert 'make_build(imp->source, &dep, depth + 1U, 0)' in s
assert 'make_build(goals[i], &result, 0U, 0)' in s
print('Native MAKE packed dependency reference: OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
