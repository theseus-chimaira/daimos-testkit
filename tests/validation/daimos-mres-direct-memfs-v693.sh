#!/bin/sh
# Native PDP-6 test of production MEMFS reclaim/shutdown direct call entries.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mres-memfs-v693.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
python3 - "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" "$work/entries.s" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s[s.index('fs_memory_reclaim:'):s.index('fs_mres_no_service:')]
for name in ('memfs_reclaim_call','memfs_shutdown_call'):
 assert s.count(name+':')==1
assert s.count('pushj   17,kret_zero')==2
Path(sys.argv[2]).write_text('.text\n.globl fs_memory_reclaim\n.globl fs_memfs_shutdown\n.globl memfs_reclaim_call\n.globl memfs_shutdown_call\n'+s)
PY
cat > "$work/test.s" <<'EOF'
.text
.globl main
.globl __test_exit
main:
    movei 1,017
    movei 2,1
    pushj 17,fs_memory_reclaim
    jumpn 1,fail
    pushj 17,fs_memfs_shutdown
    jumpn 1,fail
    movei 3,reclaim_service
    hrrm 3,memfs_reclaim_call
    movei 3,shutdown_service
    hrrm 3,memfs_shutdown_call
    movei 1,017
    movei 2,1
    pushj 17,fs_memory_reclaim
    caie 1,012345
    jrst fail
    pushj 17,fs_memfs_shutdown
    caie 1,012346
    jrst fail
    setz 1,
    popj 17,
fail:
    movei 1,1
    popj 17,
reclaim_service:
    movei 1,012345
    popj 17,
shutdown_service:
    movei 1,012346
    popj 17,
.globl kret_zero
kret_zero:
    setz 1,
    popj 17,
.globl bcache_reclaim
bcache_reclaim:
    setz 1,
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 20000 --timeout 15 --workdir "$work/run" \
 --name daimos-mres-memfs-native-v693 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/entries.s" "$work/test.s" > "$work/log" 2>&1 || {
 cat "$work/log"; exit 1;
 }
echo 'v693: MEMFS absent default and patched reclaim/shutdown calls PASS (PDP-6)'
