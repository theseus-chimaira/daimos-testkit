#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
proc="$DAIMOS_REPO/system/kernel/proc/proc.h"
sys="$DAIMOS_REPO/system/kernel/proc/syscall.h"
run="$DAIMOS_REPO/system/kernel/proc/proc_run.s"
ctl="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"

grep -q 'PROC_CRED_OFFSET' "$proc" || { echo 'credentials: missing u-area credential word' >&2; exit 1; }
grep -q 'PROC_UID' "$proc" || { echo 'credentials: missing UID accessor' >&2; exit 1; }
grep -q 'PROC_GID' "$proc" || { echo 'credentials: missing GID accessor' >&2; exit 1; }
grep -q 'SYS_PROCCTL_GETUID' "$sys" || { echo 'credentials: missing GETUID ABI' >&2; exit 1; }
grep -q 'SYS_PROCCTL_GETGID' "$sys" || { echo 'credentials: missing GETGID ABI' >&2; exit 1; }
grep -q 'SYS_PROCCTL_SETUID' "$sys" || { echo 'credentials: missing SETUID ABI' >&2; exit 1; }
grep -q 'SYS_PROCCTL_SETGID' "$sys" || { echo 'credentials: missing SETGID ABI' >&2; exit 1; }
grep -q 'PROC_CRED_OFFSET(014)' "$run" || { echo 'credentials: RUN does not inherit credentials' >&2; exit 1; }
grep -q 'proc_control_getuid' "$ctl" || { echo 'credentials: GETUID not dispatched' >&2; exit 1; }
grep -q 'proc_control_setuid' "$ctl" || { echo 'credentials: SETUID not dispatched' >&2; exit 1; }
printf '%s\n' 'daimos-credentials-v1: PASS'
