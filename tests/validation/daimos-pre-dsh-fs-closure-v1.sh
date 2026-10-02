#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
shdr="$DAIMOS_REPO/system/kernel/proc/syscall.h"
fh="$DAIMOS_REPO/system/kernel/fs/vfs.h"
fa="$DAIMOS_REPO/system/kernel/fs/file_runtime.s"
d6="$DAIMOS_REPO/system/kernel/fs/d6fs_runtime.s"
lib="$DAIMOS_REPO/userland/libc/dsys.h"
cmd="$DAIMOS_REPO/userland/exec/commands.c"
for name in SYS_SEEK_SET SYS_SEEK_CUR SYS_SEEK_END; do
    grep -q "#define $name" "$shdr" || { echo "pre-dsh-fs: missing $name" >&2; exit 1; }
done
for name in dsys_seek dsys_chown dsys_rmdir dsys_utime; do
    grep -q "$name" "$lib" || { echo "pre-dsh-fs: missing libc $name" >&2; exit 1; }
done
grep -A10 'struct vfs_stat' "$fh" | grep -q 'kword_t mtime' || { echo 'pre-dsh-fs: stat lacks mtime' >&2; exit 1; }
grep -q '^file_seek:' "$fa" || { echo 'pre-dsh-fs: seek implementation missing' >&2; exit 1; }
grep -q 'd6fs_provider_utime' "$d6" || { echo 'pre-dsh-fs: D6FS utime missing' >&2; exit 1; }
grep -q 'st->size_words' "$d6" || { echo 'pre-dsh-fs: D6FS word-size stat handling missing' >&2; exit 1; }
grep -q 'cmd_touch' "$cmd" || { echo 'pre-dsh-fs: TOUCH command missing' >&2; exit 1; }
grep -q 'cmd_date' "$cmd" || { echo 'pre-dsh-fs: DATE command missing' >&2; exit 1; }
printf '%s\n' 'daimos-pre-dsh-fs-closure-v1: PASS'
