#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

dispatch="$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s"
proc_asm="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
exec_load="$DAIMOS_REPO/system/kernel/proc/exec_load.s"
run="$DAIMOS_REPO/system/kernel/proc/proc_run.s"

section_has_root()
{
        start=$1
        stop=$2
        sed -n "/^${start}:/,/^${stop}:/p" "$dispatch" |
            grep -q 'file_check_root'
}

section_has_root native_sys_dtfs_mount native_sys_unmount || {
        echo 'multiuser-auth: DTFS mount is not root-only' >&2
        exit 1
}
section_has_root native_sys_unmount native_sys_flock || {
        echo 'multiuser-auth: unmount is not root-only' >&2
        exit 1
}
section_has_root native_sys_mount_handoff native_sys_dup2 || {
        echo 'multiuser-auth: validated filesystem mounts are not root-only' >&2
        exit 1
}
section_has_root native_sys_rtctl native_sys_procctl || {
        echo 'multiuser-auth: RT acquisition is not root-gated' >&2
        exit 1
}
sed -n '/^%L136:/,/^%L137:/p' "$dispatch" | grep -q 'file_check_root' || {
        echo 'multiuser-auth: HALT is not root-only' >&2
        exit 1
}

grep -q '^proc_event_uid_check:' "$proc_asm" || {
        echo 'multiuser-auth: process-event UID authorization is missing' >&2
        exit 1
}
grep -q 'UID 0 may administer all users' "$proc_asm" || {
        echo 'multiuser-auth: process-event root override is missing' >&2
        exit 1
}
sed -n '/^proc_nice_current:/,/^proc_nice_store:/p' "$proc_asm" |
    grep -q 'caml.*1,3' || {
        echo 'multiuser-auth: ordinary users may still raise scheduler priority' >&2
        exit 1
}
grep -A8 'trnn.*RT_REQUIRED' "$exec_load" | grep -q 'file_check_root' || {
        echo 'multiuser-auth: RT_REQUIRED exec admission is not root-only' >&2
        exit 1
}
if ! grep -q 'subi.*PROC_ROOT_RESERVED_SLOTS' "$run" ||
    ! grep -q 'caml.*012,011' "$run"; then
        echo 'multiuser-auth: root process-slot reserve is missing' >&2
        exit 1
fi

printf '%s\n' 'daimos-multiuser-kernel-auth-v1: PASS'
