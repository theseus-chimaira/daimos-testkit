#!/bin/sh
# Source-linked host C89 and native target-source admission placement.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-pure-attach-v1563.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
includes="-I$DAIMOS_REPO/tools/host"
for d in boot core drivers fs ipc mm modules proc storage; do
    includes="$includes -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
${CC:-cc} -std=c89 -Wall -Wextra -Werror $includes \
    "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" \
    "$self/daimos-dtfs-pure-attach-v1563.c" -o "$work/check"
"$work/check"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys

repo = Path(sys.argv[1])
src = (repo / 'system/kernel/proc/proc_pure_attach.c').read_text()
exec_src = (repo / 'system/kernel/proc/exec_load.s').read_text()
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
assert src.count('vfs_dtfs_owner_admit_v1562(backing)') == 1
assert src.index('vfs_dtfs_owner_admit_v1562(backing)') < src.index(
    'proc_swap_records[slot].state = packed')
assert src.index('vfs_dtfs_owner_admit_v1562(backing)') < src.index(
    'PROC_CRED_WORD(&proc_table[slot]) |=')
assert src.index('vfs_dtfs_owner_admit_v1562(backing)') < src.index(
    'proc_table[slot].sched =')
assert exec_src.count('pushj   17,proc_swap_attach') == 2
assert vfs.count('pushj   17,proc_swap_mount_busy') == 1
print('PASS v1563: no-yield PURE owner publication and RUN/EXEC sites')
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    $includes -S "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" \
    -o "$work/proc_pure_attach_v1563.s"
grep -q 'vfs_dtfs_owner_admit_v1562' "$work/proc_pure_attach_v1563.s"
echo 'PASS v1563: real KCC PDP-6 attachment invokes DTFS gate'
