#!/bin/sh
# Execute the candidate dispatcher with the existing native lock oracle.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-fs-mres-native-v681.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work/gateway.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
start=s.index('fs_provider_reg_call:')
end=s.index('; KCORE memory-pressure bridge', start)
s=s[start:end]
fast='        hrrz    7,fs_memfs_service_jump(7)\n        jrst    (7)'
locked=('        hrrz    7,fs_memfs_service_jump(7)\n'
        '        ; The missing-service trampoline already returns -1 normally.\n'
        '        ; Invoke it under the same lease and use the common unlock path.\n'
        '        pushj   17,(7)')
assert s.count(fast)==1 and s.count(locked)==1
s=s.replace(fast,'        jrst    @fs_memfs_service_jump(7)')
s=s.replace(locked,'        pushj   17,@fs_memfs_service_jump(7)')
prefix='\n'.join('.globl '+x for x in ('fs_provider_reg_call',
    'fs_dtfs_service_jump','fs_memfs_service_jump',
    'fs_d6fs_service_jump','fs_tsfs_service_jump'))
Path(sys.argv[2]).write_text(prefix+'\n'+s)
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 300000 --timeout 20 --workdir "$work/run" \
  --name daimos-fs-mres-indirect-native-v681 --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$self/daimos-provider-lock-native-v327.s" \
  "$work/gateway.s" > "$work/log" 2>&1 || { tail -60 "$work/log"; exit 1; }
echo 'v681: PDP-6 indirect dispatch, lock wait/retry, missing provider PASS'
