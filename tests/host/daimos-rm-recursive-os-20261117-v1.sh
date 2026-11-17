#!/bin/sh
# Structural DAIMOS OS regression for recursive RM and assembler RM removal.
# The independent KCC MAKE suffix/CLEAN assertions are now owned by
# pdp10-testkit/misc/kcc-host/kcc-native-make-clean-suffix-20261010-v1.sh.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1]); c=(root/'userland/exec/commands.c').read_text(); docs=(root/'userland/manual/RM.SIXMD').read_text(); asm=(root/'userland/optional/asmutils/Makefile').read_text()
assert not (root/'userland/optional/asmutils/RM.S').exists()
assert not re.search(r'^RM: RM\.S|\$\(CP\) RM(?:\.S)? ',asm,re.M)
assert 'rm_tree(child, depth + 1U)' in c and 'dsys_rmdir(path)' in c
assert 'VFS_TYPE_MOUNTSRC' in c and 'RM_MAX_DEPTH' in c
assert 'RM [-R] [-F]' in docs
print('PASS: DAIMOS recursive RM -R implementation and obsolete assembler RM removal')
PY
