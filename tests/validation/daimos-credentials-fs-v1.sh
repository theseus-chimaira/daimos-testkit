#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
vh="$DAIMOS_REPO/system/kernel/fs/vfs.h"
fc="$DAIMOS_REPO/system/kernel/fs/file.c"
d6="$DAIMOS_REPO/system/kernel/fs/d6fs_provider.c"
d6a="$DAIMOS_REPO/system/kernel/fs/d6fs_runtime.s"
grep -A8 'struct vfs_stat' "$vh" | grep -q 'unsigned int uid' || { echo 'cred-fs: vfs_stat lacks uid' >&2; exit 1; }
grep -A9 'struct vfs_stat' "$vh" | grep -q 'unsigned int gid' || { echo 'cred-fs: vfs_stat lacks gid' >&2; exit 1; }
grep -q 'file_check_access' "$fc" || { echo 'cred-fs: no generic access check' >&2; exit 1; }
grep -q 'D6FS_FCB_OWNER' "$d6" || { echo 'cred-fs: create does not stamp owner' >&2; exit 1; }
grep -A70 '^d6fs_provider_stat:' "$d6a" | grep -q 'st->uid' || { echo 'cred-fs: D6FS stat does not export uid' >&2; exit 1; }
printf '%s\n' 'daimos-credentials-fs-v1: PASS'
