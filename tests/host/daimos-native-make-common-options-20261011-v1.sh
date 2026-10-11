#!/bin/sh
# Verify native MAKE common-option dispatch and build the target compiler unit.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
python3 - "$DAIMOS_REPO/userland/exec/make.c" <<'PY'
import pathlib
import sys

s = pathlib.Path(sys.argv[1]).read_text()
assert 'make_suffix_configured = 1;' in s
assert 'make_suffix_enabled(rn,' in s
assert '!make_no_implicit && make_source_rule' in s
assert 'MAKE_RULE_PRECIOUS' in s
assert 'MAKE_RULE_SILENT' in s
assert 'MAKE_RULE_IGNORE' in s
assert 'make_ignore = 1;' in s
assert 'make_touch = 1;' in s
assert 'dsys_utime(path, now)' in s
assert "arg[j] == 'j' || arg[j] == 'J'" in s
assert 'make_run_commands(recipe, &automatic,' in s
print('Native MAKE shared-option source invariants: OK')
PY
make -C "$DAIMOS_REPO/userland" \
    "$DAIMOS_REPO/build/userland/make/exec/make.dobj" \
    PDP10_PREFIX="$PDP10_PREFIX"
