#!/bin/sh
# Identify unsafe error branch after an ambiguously durable FCB create.
set -eu
: "${DAIMOS_REPO:?specify DAIMOS_REPO}"
python3 - "$DAIMOS_REPO/system/kernel/fs/d6fs_provider_namespace_pdp6.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
create=s.split('d6fs_provider_create_object:',1)[1].split('; int d6fs_provider_unlink(',1)[0]
first=create.index('pushj   17,d6fs_reader_put_fcb')
sub=create[first: create.index('d6fs_create_dirent:',first)]
if 'jumpn   1,d6fs_create_fail' not in sub:
    print('CHANGED: creation no longer directly fails on FCB publication error')
    raise SystemExit(0)
print('KNOWN DEFECT: ambiguous FCB create returns failure without a recovery decision')
print('NOTE: source audit, not runtime fault acceptance; do not reclaim potentially durable FCB blindly')
PY
