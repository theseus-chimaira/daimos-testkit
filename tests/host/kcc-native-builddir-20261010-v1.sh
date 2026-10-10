#!/bin/sh
# Check that the native KCC build directory was renamed without losing outputs.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import subprocess,sys,re
root=Path(sys.argv[1]);old=subprocess.check_output(['git','-C',str(root),'show','cdb7538:daimos.mk'],text=True)
new=(root/'daimos.mk').read_text()
old=old.replace('NATIVE_BUILD_DIR = B','NATIVE_BUILD_DIR = BUILD')
old=re.sub(r'(?<![A-Za-z0-9_])B/','BUILD/',old)
old=old.replace('NATIVE: B ','NATIVE: BUILD ').replace('\nB:\n','\nBUILD:\n').replace('0777 B\n','0777 BUILD\n')
old=old.replace('# Native DAIMOS KCC build. Source and object inventory is in MAKEFILE.','# Native DAIMOS KCC build. Generated files are kept in BUILD/.')
old=old.replace('# Archive recipes use $^: ordered prerequisites, supported by GNU/BSD/DAIMOS MAKE.\n# Do not apply this to DLINK: startup objects must precede archives.', '# Archive and DLINK recipes use ordered prerequisites with $^.\n# DLINK dependencies put startup objects before phase archives.')
assert new==old+'\t-@/SYSTEM/EXEC/RMDIR BUILD\n'
assert 'CLEAN:\n' in new
print('PASS: all native build paths renamed and empty directory cleanup added')
PY
