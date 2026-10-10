#!/bin/sh
# Verify bare-tool direct recipe resolution and absolute installation outputs.
set -eu
: "${DAIMOS_REPO:?}"
: "${KCC_REPO:?}"
python3 - "$DAIMOS_REPO" "$KCC_REPO" <<'PY'
from pathlib import Path
import sys

da, kc = (Path(x) for x in sys.argv[1:])
source = (da / 'userland/exec/make.c').read_text()
mk = (kc / 'daimos.mk').read_text()
assert 'make_direct_path(path, token)' in source
assert 'make_find_var("PATH")' in source
assert 'dsys_stat(path, &st)' in source
assert 'st.type == VFS_TYPE_REG' in source
assert 'u_s6_pack(path, U_PATH_WORDS, command)' in source
for name in ('KCC', 'DAS', 'DARC', 'DLINK', 'INSTALL', 'RM'):
    assert ' = ' + name + '\n' in mk
assert '$(NATIVE_KCC_LIBEXEC)/KCPP' in mk
assert 'NATIVE_KCC_DEST = /OPTION/BASE/EXEC/KCC' in mk and 'BUILD/KCC.DXR $(NATIVE_KCC_DEST)' in mk
assert '/SYSTEM/EXEC/INSTALL' not in mk
assert '/OPTION/BASE/EXEC/DAS' not in mk
assert mk.split('CLEAN:\n',1)[1].strip() == '@$(NATIVE_RM) -R -F BUILD'
print('PASS: native MAKE resolves command names through PATH')
PY
