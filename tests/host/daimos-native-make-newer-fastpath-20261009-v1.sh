#!/bin/sh
# Compile the native MAKE fast path and verify its guarded query structure.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
source="$DAIMOS_REPO/userland/exec/make.c"
python3 - "$source" <<'PY'
import pathlib, sys
s = pathlib.Path(sys.argv[1]).read_text()
assert 'if (need && recipe != MAKE_NONE && make_uses_newer(recipe))' in s
assert s.index('if (need && recipe != MAKE_NONE && make_uses_newer(recipe))') < s.index('if (need && recipe != MAKE_NONE) {')
assert 'if (make_has_newer(value))' in s
assert 'make_any_var_newer = 1' in s
assert 'make_newer_buf[0] = 0;' in s
print('Native MAKE newer-list fast path: structural checks OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
