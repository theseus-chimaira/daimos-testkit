#!/bin/sh
# Ensure phony targets avoid filesystem metadata queries.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
a=s.index('static int\nmake_build(')
b=s.index('static int\nmake_command_assignment(',a)
x=s[a:b]
assert 'target.mtime = 0UL;' in x
assert 'target.exists = 0U;' in x
assert '(rule->flags & MAKE_RULE_PHONY) != 0U' in x
assert 'else if (make_stat(name, &target) != 0)' in x
assert 'if (!make_dry_run && (rule == 0 ||' in x
print('Native MAKE PHONY stat bypass: structural checks OK')
PY
make -C "$DAIMOS_REPO/userland" "$DAIMOS_REPO/build/userland/make/exec/make.dobj" PDP10_PREFIX="$PDP10_PREFIX"
