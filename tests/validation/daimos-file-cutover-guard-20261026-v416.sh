#!/bin/sh
# Validate that the atomic FILE v416 layout conversion is complete.
# This gate is expected to FAIL on the original descriptor format.
set -eu

repo=${DAIMOS_REPO:-"$(CDPATH= cd -- "$(dirname -- "$0")/../../../DAIMOS" && pwd)"}
cd "$repo"

fail=0
for spec in \
    'system/kernel/fs/file_runtime.s:file_mount_ext_' \
    'system/kernel/fs/file_runtime.s:file_lock_mount_ext_v319' \
    'system/kernel/fs/file_runtime.s:007040' \
    'system/kernel/fs/file.c:file_mount_ext_store' \
    'system/kernel/fs/file.h:FILE_META_OWNER_MASK' \
    'system/kernel/proc/proc_run.s:PROC_FDMOUNT_OFFSET' \
    'system/kernel/ipc/pipe.s:041(010)' \
    'system/kernel/proc/proc.h:PROC_FDMOUNT_OFFSET'; do
    path=${spec%%:*}
    pattern=${spec#*:}
    if grep -F -q -- "$pattern" "$path"; then
        printf 'NOT CONVERTED: %s contains %s\n' "$path" "$pattern"
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    echo 'FILE cutover guard: FAIL (old-format references remain)'
    exit 1
fi
echo 'FILE cutover guard: PASS (no enumerated old-format references)'
